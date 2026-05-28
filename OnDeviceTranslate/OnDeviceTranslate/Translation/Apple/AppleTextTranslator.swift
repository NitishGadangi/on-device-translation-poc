import Foundation

/// `TextTranslator` backed by Apple's Translation framework via the coordinator.
/// `@unchecked Sendable`: the only stored reference is an immutable handle to the
/// `@MainActor` coordinator, always reached through main-actor-isolated `await`s.
final class AppleTextTranslator: TextTranslator, @unchecked Sendable {
    private let coordinator: TranslationCoordinator

    init(coordinator: TranslationCoordinator) {
        self.coordinator = coordinator
    }

    func prepare(_ pair: LanguagePair) async throws {
        try await coordinator.prepare(pair)
    }

    func translate(_ texts: [String],
                   from source: Locale.Language?,
                   to target: Locale.Language) async throws -> [String: String] {
        try await coordinator.translate(texts, from: source, to: target)
    }
}
