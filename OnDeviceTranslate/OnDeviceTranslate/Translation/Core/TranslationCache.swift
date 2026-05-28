import Foundation

/// In-memory translation cache keyed by (source, target, text). An actor so the
/// pipeline can read/write it safely off the main thread.
actor TranslationCache {
    private struct Key: Hashable {
        let source: String
        let target: String
        let text: String
    }

    private var store: [Key: String] = [:]

    func value(text: String, source: Locale.Language?, target: Locale.Language) -> String? {
        store[key(text, source, target)]
    }

    func insert(_ translated: String, text: String, source: Locale.Language?, target: Locale.Language) {
        store[key(text, source, target)] = translated
    }

    func clear() {
        store.removeAll()
    }

    var count: Int { store.count }

    private func key(_ text: String, _ source: Locale.Language?, _ target: Locale.Language) -> Key {
        Key(source: source?.maximalIdentifier ?? "auto",
            target: target.maximalIdentifier,
            text: text)
    }
}
