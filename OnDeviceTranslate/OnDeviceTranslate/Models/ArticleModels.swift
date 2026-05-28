import Foundation

struct ArticleDetail: Codable {
    let id: String
    let title: String
    let subtitle: String
    let heroImageUrl: String
    let author: ArticleAuthor
    let publishedAt: String
    let readMinutes: Int
    let blocks: [ContentBlock]
    let relatedLinks: [RelatedLink]
}

struct ArticleAuthor: Codable {
    let name: String
    let bio: String
    let avatarUrl: String
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
    let attribution: String?
    let items: [String]?
    let language: String?

    enum Kind: String {
        case heading, paragraph, quote, bullet, code
    }
    var kind: Kind { Kind(rawValue: type) ?? .paragraph }
}

struct RelatedLink: Codable, Identifiable {
    let title: String
    let url: String
    var id: String { url }
}
