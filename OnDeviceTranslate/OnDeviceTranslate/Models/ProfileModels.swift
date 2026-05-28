import Foundation

struct ProfileResponse: Codable {
    let name: String
    let handle: String
    let bio: String
    let location: String
    let joinedAt: String
    let stats: ProfileStats
    let badges: [String]
    let comments: [Comment]
}

struct ProfileStats: Codable {
    let posts: Int
    let followers: Int
    let following: Int
}

struct Comment: Codable, Identifiable {
    let id: String
    let author: String
    let text: String
    let createdAt: String
    let likes: Int
}
