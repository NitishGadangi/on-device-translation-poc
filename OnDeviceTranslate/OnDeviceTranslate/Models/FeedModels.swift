import Foundation

struct FeedResponse: Codable {
    let screenTitle: String
    let subtitle: String
    let items: [FeedItem]
}

struct FeedItem: Codable, Identifiable, Hashable {
    let id: String
    let category: String
    let title: String
    let summary: String
    let author: String
    let authorRole: String
    let publishedAt: String
    let readMinutes: Int
    let tags: [String]
    let thumbnailUrl: String
    let slug: String
    let likeCount: Int
    let commentCount: Int
}
