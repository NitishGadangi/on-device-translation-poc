import Foundation

/// Base URL for the screen JSON, served from the repo's raw GitHub content.
/// Each `Endpoint.path` ("api/<screen>.json") is appended to this.
enum NetworkConfig {
    static let rawBaseURL = "https://raw.githubusercontent.com/NitishGadangi/on-device-translation-poc/refs/heads/master/"
}

/// A screen's data source: a remote path plus a bundled JSON fallback.
struct Endpoint {
    let path: String
    let bundleResource: String

    var remoteURL: URL? { URL(string: NetworkConfig.rawBaseURL + path) }

    static let feed = Endpoint(path: "api/feed.json", bundleResource: "feed")
    static let detail = Endpoint(path: "api/detail.json", bundleResource: "detail")
    static let profile = Endpoint(path: "api/profile.json", bundleResource: "profile")
}
