import Foundation
import Combine

/// The single seam where translation plugs into the data flow:
/// fetch raw Data → (optionally) translate at the parse layer → decode plain Codable.
@MainActor
final class APIClient: ObservableObject {
    private let network: NetworkService
    private let responseTranslator: ResponseTranslator
    private let settings: DebugSettings
    private let cache: TranslationCache
    private let decoder = JSONDecoder()

    init(network: NetworkService,
         responseTranslator: ResponseTranslator,
         settings: DebugSettings,
         cache: TranslationCache) {
        self.network = network
        self.responseTranslator = responseTranslator
        self.settings = settings
        self.cache = cache
    }

    func clearCache() async { await cache.clear() }
    func cacheCount() async -> Int { await cache.count }

    func fetch<T: Decodable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        let raw = try await network.data(for: endpoint, offline: settings.useOfflineData)

        guard settings.isTranslationActive else {
            return try decoder.decode(T.self, from: raw)
        }

        let (translated, stats) = await responseTranslator.translate(
            raw,
            source: settings.resolvedSourceLanguage,
            target: settings.resolvedTargetLanguage,
            useCache: settings.useCache
        )
        settings.recordStats(stats)
        return try decoder.decode(T.self, from: translated)
    }
}
