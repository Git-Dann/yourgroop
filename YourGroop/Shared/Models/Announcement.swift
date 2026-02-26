import Foundation

struct Announcement: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let groopId: UUID
    var title: String
    var body: String
    var createdAt: Date
}
