import Foundation

struct GroopMember: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let groopId: UUID
    let name: String
    let jobTitle: String
    let status: String
    let isHost: Bool
}
