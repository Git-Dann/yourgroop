import Foundation

struct Groop: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var category: String
    var location: String
    var memberCount: Int
    var isJoined: Bool
}
