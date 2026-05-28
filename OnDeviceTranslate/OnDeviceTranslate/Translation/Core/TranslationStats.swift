import Foundation

/// One translated string, surfaced in the Debug panel's "show original + translated" log.
struct TranslationRecord: Identifiable, Sendable {
    let id = UUID()
    let path: String
    let original: String
    let translated: String
    let detectedLanguage: String?
    let cacheHit: Bool
}

/// Outcome of translating one response, consumed by the Debug panel.
struct TranslationStats: Sendable {
    var records: [TranslationRecord] = []
    var totalStrings = 0
    var translatedStrings = 0
    var skippedStrings = 0
    var cacheHits = 0
    var processingTime: TimeInterval = 0
}
