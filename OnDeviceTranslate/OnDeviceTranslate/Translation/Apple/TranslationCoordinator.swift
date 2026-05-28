import Foundation
import SwiftUI
import Translation
import Combine

/// Bridges the SwiftUI-bound `TranslationSession` to a plain `async` API the
/// networking layer can await. The session can only be vended inside a view's
/// `.translationTask`, so this coordinator parks pending work in a queue and the
/// hidden `TranslationHostView` drains it whenever a session becomes available.
///
/// `@MainActor` because it drives a `@Published` SwiftUI configuration. The heavy
/// ML translation runs async off-main inside the framework; only this lightweight
/// orchestration touches the main actor.
@MainActor
final class TranslationCoordinator: ObservableObject {

    /// Drives the host view's `.translationTask`. Changing it (or invalidating it)
    /// re-runs the task and yields a fresh session.
    @Published private(set) var configuration: TranslationSession.Configuration?

    private struct PendingBatch {
        var texts: Set<String> = []
        var waiters: [(texts: [String], continuation: CheckedContinuation<[String: String], Error>)] = []
    }

    private var pending: [LanguagePair: PendingBatch] = [:]
    private var prepareWaiters: [LanguagePair: [CheckedContinuation<Void, Error>]] = [:]
    private var activePair: LanguagePair?
    private var currentPair: LanguagePair?

    // MARK: - Public async API (used by AppleTextTranslator)

    func translate(_ texts: [String],
                   from source: Locale.Language?,
                   to target: Locale.Language) async throws -> [String: String] {
        guard !texts.isEmpty else { return [:] }
        guard TranslationAvailability.isPlatformSupported else { throw TranslationError.unsupportedPlatform }
        let pair = LanguagePair(source: source, target: target)
        return try await withCheckedThrowingContinuation { continuation in
            var batch = pending[pair] ?? PendingBatch()
            batch.texts.formUnion(texts)
            batch.waiters.append((texts, continuation))
            pending[pair] = batch
            wake(pair)
        }
    }

    func prepare(_ pair: LanguagePair) async throws {
        guard TranslationAvailability.isPlatformSupported else { throw TranslationError.unsupportedPlatform }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            prepareWaiters[pair, default: []].append(continuation)
            wake(pair)
        }
    }

    // MARK: - Triggering the translationTask

    private func wake(_ pair: LanguagePair) {
        if activePair == pair { return }   // a live closure will pick up the new work
        if currentPair == pair {
            configuration?.invalidate()    // same languages: re-fire the task for new text
        } else {
            currentPair = pair
            configuration = TranslationSession.Configuration(source: pair.source, target: pair.target)
        }
    }

    // MARK: - Drained by TranslationHostView

    func drain(using session: TranslationSession) async {
        guard let configuration else { return }
        let pair = LanguagePair(source: configuration.source,
                                target: configuration.target ?? Locale.Language(identifier: "en"))
        activePair = pair
        defer { activePair = nil }

        if let waiters = prepareWaiters.removeValue(forKey: pair), !waiters.isEmpty {
            do {
                try await session.prepareTranslation()
                waiters.forEach { $0.resume() }
            } catch {
                waiters.forEach { $0.resume(throwing: error) }
            }
        }

        while let batch = pending[pair], !batch.waiters.isEmpty {
            pending[pair] = nil
            await run(batch, session: session)
        }
    }

    private func run(_ batch: PendingBatch, session: TranslationSession) async {
        let requests = batch.texts.map { TranslationSession.Request(sourceText: $0, clientIdentifier: $0) }
        do {
            let responses = try await session.translations(from: requests)
            var map: [String: String] = [:]
            for response in responses {
                map[response.clientIdentifier ?? response.sourceText] = response.targetText
            }
            for waiter in batch.waiters {
                let slice = waiter.texts.reduce(into: [String: String]()) { result, text in
                    if let translated = map[text] { result[text] = translated }
                }
                waiter.continuation.resume(returning: slice)
            }
        } catch {
            batch.waiters.forEach { $0.continuation.resume(throwing: error) }
        }
    }
}
