import Foundation

/// The plug-in seam: takes a raw JSON response body, translates every string that
/// the rule engine + language detector deem non-English, and returns byte-faithful
/// JSON with only those leaves rewritten. Runs entirely off the main thread (actor)
/// and never throws — any failure falls back to the original data.
actor ResponseTranslator {
    private let translator: TextTranslator
    private let cache: TranslationCache
    private let filter: TranslationFilter
    private let detector: LanguageDetector
    private let maxLeafCount: Int

    init(translator: TextTranslator,
         cache: TranslationCache,
         filter: TranslationFilter = TranslationFilter(),
         detector: LanguageDetector = LanguageDetector(),
         maxLeafCount: Int = 5000) {
        self.translator = translator
        self.cache = cache
        self.filter = filter
        self.detector = detector
        self.maxLeafCount = maxLeafCount
    }

    /// - Parameters:
    ///   - source: fixed source language, or `nil` to auto-detect per string.
    ///   - useCache: when false, bypasses cache reads (writes still happen).
    func translate(_ data: Data,
                   source configuredSource: Locale.Language?,
                   target: Locale.Language,
                   useCache: Bool = true) async -> (data: Data, stats: TranslationStats) {
        let start = Date()
        var stats = TranslationStats()

        guard let root = try? JSONParser.parse(data) else { return (data, stats) }

        var leaves: [JSONValue.StringLeaf] = []
        root.collectStrings(into: &leaves)
        stats.totalStrings = leaves.count
        guard !leaves.isEmpty, leaves.count <= maxLeafCount else { return (data, stats) }

        var context: [String: (key: String?, path: String)] = [:]
        for leaf in leaves where context[leaf.text] == nil {
            context[leaf.text] = (leaf.key, leaf.path)
        }

        var groups: [String: (language: Locale.Language, texts: [String])] = [:]
        var detectedByText: [String: Locale.Language] = [:]
        var skipped = 0
        for (text, ctx) in context {
            guard filter.shouldTranslate(text, key: ctx.key) else { skipped += 1; continue }
            let source = configuredSource ?? detector.detectSourceLanguage(for: text)
            guard let source else { skipped += 1; continue }
            detectedByText[text] = source
            groups[source.maximalIdentifier, default: (source, [])].texts.append(text)
        }

        var translationMap: [String: String] = [:]
        var cacheHits: Set<String> = []
        for (_, group) in groups {
            var misses: [String] = []
            for text in group.texts {
                if useCache, let cached = await cache.value(text: text, source: group.language, target: target) {
                    translationMap[text] = cached
                    cacheHits.insert(text)
                } else {
                    misses.append(text)
                }
            }
            guard !misses.isEmpty else { continue }
            do {
                let result = try await translator.translate(misses, from: group.language, to: target)
                for (original, translated) in result {
                    translationMap[original] = translated
                    await cache.insert(translated, text: original, source: group.language, target: target)
                }
            } catch {
                continue
            }
        }

        stats.skippedStrings = skipped
        stats.translatedStrings = translationMap.count
        stats.cacheHits = cacheHits.count
        stats.records = translationMap.map { original, translated in
            TranslationRecord(path: context[original]?.path ?? "$",
                              original: original,
                              translated: translated,
                              detectedLanguage: detectedByText[original]?.languageCode?.identifier,
                              cacheHit: cacheHits.contains(original))
        }.sorted { $0.path < $1.path }
        stats.processingTime = Date().timeIntervalSince(start)

        guard !translationMap.isEmpty else { return (data, stats) }
        return (root.replacingStrings(translationMap).encode(), stats)
    }
}
