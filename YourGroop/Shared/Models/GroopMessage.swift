import Foundation

struct GroopMessage: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let groopId: UUID
    let senderName: String
    let body: String
    let createdAt: Date
    let isFromCurrentUser: Bool
}
