import Foundation
import Translation

enum TranslationSupport: Equatable, Sendable {
    case unsupportedSimulator
    case unsupportedPair
    case needsDownload
    case ready

    /// Whether the master translation toggle should be enabled.
    var allowsTranslation: Bool {
        self == .ready || self == .needsDownload
    }

    var message: String? {
        switch self {
        case .unsupportedSimulator:
            return "Apple Translation runs only on a physical device — not the Simulator. Run on a real iPhone/iPad to enable translation."
        case .unsupportedPair:
            return "This language pair isn't supported by Apple Translation on this device."
        case .needsDownload:
            return "The language model isn't downloaded yet. Translating once will prompt the system to download it."
        case .ready:
            return nil
        }
    }
}

/// Gates translation on platform + model availability. Detection (NaturalLanguage)
/// works in the Simulator, but the Translation framework itself does not.
struct TranslationAvailability {
    static var isPlatformSupported: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    static func check(from source: Locale.Language, to target: Locale.Language) async -> TranslationSupport {
        #if targetEnvironment(simulator)
        return .unsupportedSimulator
        #else
        let status = await LanguageAvailability().status(from: source, to: target)
        switch status {
        case .installed: return .ready
        case .supported: return .needsDownload
        case .unsupported: return .unsupportedPair
        @unknown default: return .unsupportedPair
        }
        #endif
    }
}
