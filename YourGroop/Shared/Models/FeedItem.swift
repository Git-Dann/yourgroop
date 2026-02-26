import Foundation

struct FeedItem: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let groopId: UUID
    let message: String
    let timestamp: Date
}
