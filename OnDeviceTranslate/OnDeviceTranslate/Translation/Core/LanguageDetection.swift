import Foundation
import NaturalLanguage

/// Detects the dominant language of a string so the pipeline can skip text that
/// is already English (or undetermined) and translate the rest.
struct LanguageDetector: Sendable {
    var minimumConfidence: Double = 0.50

    /// Returns the source language to translate from, or `nil` to skip
    /// (English, undetermined, or below the confidence threshold).
    func detectSourceLanguage(for text: String) -> Locale.Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage, dominant != .english else { return nil }
        let confidence = recognizer.languageHypotheses(withMaximum: 1)[dominant] ?? 0
        guard confidence >= minimumConfidence else { return nil }
        return Locale.Language(identifier: dominant.rawValue)
    }
}
