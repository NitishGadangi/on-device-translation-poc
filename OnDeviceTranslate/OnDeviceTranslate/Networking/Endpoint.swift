import Foundation

/// Base URL for the screen JSON. After pushing this repo to GitHub, replace the
/// placeholder with your raw URL, e.g.
/// "https://raw.githubusercontent.com/<user>/on-device-translation-poc/main/"
/// Until then, keep the Debug panel's "offline data" toggle on.
enum NetworkConfig {
    static let rawBaseURL = "https://raw.githubusercontent.com/REPLACE_ME/on-device-translation-poc/main/"
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
