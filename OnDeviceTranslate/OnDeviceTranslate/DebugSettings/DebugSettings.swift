import Foundation
import Combine

/// User-facing toggles for the on-the-fly translation, persisted to UserDefaults.
/// `@MainActor` so views and the APIClient read/write it on the main actor.
@MainActor
final class DebugSettings: ObservableObject {

    enum SourceMode: String, CaseIterable, Identifiable {
        case auto, korean
        var id: String { rawValue }
        var displayName: String { self == .auto ? "Auto-detect" : "Korean (ko)" }
        var language: Locale.Language? { self == .auto ? nil : Locale.Language(identifier: "ko") }
    }

    static let targetOptions: [(code: String, name: String)] = [
        ("en", "English"), ("es", "Spanish"), ("ja", "Japanese"), ("fr", "French")
    ]

    @Published var translationEnabled: Bool { didSet { defaults.set(translationEnabled, forKey: Keys.enabled) } }
    @Published var provider: TranslationProvider { didSet { defaults.set(provider.rawValue, forKey: Keys.provider) } }
    @Published var sourceMode: SourceMode { didSet { defaults.set(sourceMode.rawValue, forKey: Keys.sourceMode) } }
    @Published var targetCode: String { didSet { defaults.set(targetCode, forKey: Keys.targetCode) } }
    @Published var useCache: Bool { didSet { defaults.set(useCache, forKey: Keys.useCache) } }
    @Published var useOfflineData: Bool { didSet { defaults.set(useOfflineData, forKey: Keys.useOfflineData) } }
    @Published var showOriginal: Bool { didSet { defaults.set(showOriginal, forKey: Keys.showOriginal) } }
    @Published var showTouches: Bool { didSet { defaults.set(showTouches, forKey: Keys.showTouches) } }

    /// Not persisted — live diagnostics for the Debug panel.
    @Published var lastStats: TranslationStats?
    @Published var availability: TranslationSupport = .ready

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        translationEnabled = defaults.bool(forKey: Keys.enabled)
        provider = TranslationProvider(rawValue: defaults.string(forKey: Keys.provider) ?? "") ?? .apple
        sourceMode = SourceMode(rawValue: defaults.string(forKey: Keys.sourceMode) ?? "") ?? .auto
        targetCode = defaults.string(forKey: Keys.targetCode) ?? "en"
        useCache = defaults.object(forKey: Keys.useCache) as? Bool ?? true
        useOfflineData = defaults.object(forKey: Keys.useOfflineData) as? Bool ?? true
        showOriginal = defaults.bool(forKey: Keys.showOriginal)
        showTouches = defaults.bool(forKey: Keys.showTouches)
    }

    var resolvedSourceLanguage: Locale.Language? { sourceMode.language }
    var resolvedTargetLanguage: Locale.Language { Locale.Language(identifier: targetCode) }

    /// The language pair the availability check / pre-warm uses (concrete source).
    var availabilityProbePair: LanguagePair {
        LanguagePair(source: Locale.Language(identifier: "ko"), target: resolvedTargetLanguage)
    }

    var isTranslationActive: Bool {
        translationEnabled && availability.allowsTranslation
    }

    /// Changes whenever a setting that affects fetched content changes, so screens
    /// re-fetch (via `.task(id:)`) and the developer sees the toggle take effect.
    var reloadSignature: String {
        [
            String(isTranslationActive), provider.rawValue, sourceMode.rawValue,
            targetCode, String(useOfflineData), String(useCache)
        ].joined(separator: "|")
    }

    func recordStats(_ stats: TranslationStats) {
        lastStats = stats
    }

    func refreshAvailability() async {
        availability = await TranslationAvailability.check(from: Locale.Language(identifier: "ko"),
                                                           to: resolvedTargetLanguage)
        if !availability.allowsTranslation && translationEnabled {
            translationEnabled = false
        }
    }

    private enum Keys {
        static let enabled = "debug.translationEnabled"
        static let provider = "debug.provider"
        static let sourceMode = "debug.sourceMode"
        static let targetCode = "debug.targetCode"
        static let useCache = "debug.useCache"
        static let useOfflineData = "debug.useOfflineData"
        static let showOriginal = "debug.showOriginal"
        static let showTouches = "debug.showTouches"
    }
}
