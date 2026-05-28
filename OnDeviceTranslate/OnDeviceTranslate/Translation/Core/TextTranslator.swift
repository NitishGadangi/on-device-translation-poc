import Foundation

/// A source/target language pairing. A `nil` source means "auto-detect".
struct LanguagePair: Hashable, Sendable {
    var source: Locale.Language?
    var target: Locale.Language
}

enum TranslationError: Error {
    case unsupportedPlatform
    case unsupportedLanguagePair
    case hostUnavailable
    case sessionFailed(Error)
}

/// Provider-agnostic translation. The networking layer depends only on this;
/// the Apple/SwiftUI specifics live behind the `AppleTextTranslator` conformance.
protocol TextTranslator: Sendable {
    /// Pre-download / warm up models for a pair. Safe to call repeatedly.
    func prepare(_ pair: LanguagePair) async throws

    /// Translate strings that share one source language. Returns a map keyed by
    /// the original input string.
    func translate(_ texts: [String],
                   from source: Locale.Language?,
                   to target: Locale.Language) async throws -> [String: String]
}
