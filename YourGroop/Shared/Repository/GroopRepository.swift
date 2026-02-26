import Foundation

protocol GroopRepository: Sendable {
    func fetchMyGroops() async -> [Groop]
    func fetchDiscoveryGroops() async -> [Groop]
    func groop(id: UUID) async -> Groop?
    func announcement(id: UUID) async -> Announcement?
    func fetchAnnouncements(for groopId: UUID) async -> [Announcement]
    func createAnnouncement(groopId: UUID, title: String, body: String) async -> Announcement
    func fetchMessages(for groopId: UUID) async -> [GroopMessage]
    func sendMessage(groopId: UUID, body: String, senderName: String, isFromCurrentUser: Bool) async -> GroopMessage
    func fetchMembers(for groopId: UUID) async -> [GroopMember]
    func joinGroop(id: UUID) async
    func createGroop(name: String, category: String, location: String, hostName: String) async -> Groop
    func feedItems(for groopId: UUID) async -> [FeedItem]
}
