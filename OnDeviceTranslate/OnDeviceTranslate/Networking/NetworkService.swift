import Foundation

enum NetworkError: Error {
    case invalidURL
    case badStatus(Int)
    case missingBundledResource(String)
}

/// Fetches raw response data. When `offline` is set (or a remote fetch fails) it
/// loads the JSON bundled in the app. Uses URLSession's async API, so it runs off
/// the main thread.
struct NetworkService {
    var session: URLSession = .shared

    func data(for endpoint: Endpoint, offline: Bool) async throws -> Data {
        if offline {
            return try bundledData(for: endpoint)
        }
        guard let url = endpoint.remoteURL else { throw NetworkError.invalidURL }
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw NetworkError.badStatus(http.statusCode)
            }
            return data
        } catch {
            return try bundledData(for: endpoint)
        }
    }

    private func bundledData(for endpoint: Endpoint) throws -> Data {
        guard let url = Bundle.main.url(forResource: endpoint.bundleResource, withExtension: "json") else {
            throw NetworkError.missingBundledResource(endpoint.bundleResource)
        }
        return try Data(contentsOf: url)
    }
}
