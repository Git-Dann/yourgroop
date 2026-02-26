import Foundation
import Observation

@MainActor
@Observable
final class InMemoryGroopRepository: GroopRepository {
    private let apiClient: APIClient
    private(set) var groops: [Groop]
    private(set) var announcements: [Announcement]
    private(set) var messages: [GroopMessage]
    private(set) var members: [GroopMember]

    init(apiClient: APIClient) {
        self.apiClient = apiClient

        let runGroop = Groop(
            id: UUID(uuidString: "A1111111-1111-1111-1111-111111111111") ?? UUID(),
            name: "Northern Runners MCR",
            category: "Fitness",
            location: "Manchester City Centre",
            memberCount: 64,
            isJoined: true
        )

        let readingGroop = Groop(
            id: UUID(uuidString: "B2222222-2222-2222-2222-222222222222") ?? UUID(),
            name: "Ancoats Book Circle",
            category: "Books",
            location: "Ancoats, Manchester",
            memberCount: 37,
            isJoined: true
        )

        let discoveryGroop = Groop(
            id: UUID(uuidString: "C3333333-3333-3333-3333-333333333333") ?? UUID(),
            name: "Chorlton Board Game Nights",
            category: "Games",
            location: "Chorlton-cum-Hardy",
            memberCount: 29,
            isJoined: false
        )

        let cookingGroop = Groop(
            id: UUID(uuidString: "D4444444-4444-4444-4444-444444444444") ?? UUID(),
            name: "Salford Quays Creatives",
            category: "Arts",
            location: "Salford Quays",
            memberCount: 25,
            isJoined: false
        )

        let hikingGroop = Groop(
            id: UUID(uuidString: "E5555555-5555-5555-5555-555555555555") ?? UUID(),
            name: "Peak District Weekend Hikers",
            category: "Outdoors",
            location: "Stockport",
            memberCount: 41,
            isJoined: false
        )

        let campfieldGroop = Groop(
            id: UUID(uuidString: "F6666666-6666-6666-6666-666666666666") ?? UUID(),
            name: "Campfield Co-Working Circle",
            category: "Co-Working",
            location: "Campfield, Manchester",
            memberCount: 52,
            isJoined: true
        )

        self.groops = [runGroop, readingGroop, discoveryGroop, cookingGroop, hikingGroop, campfieldGroop]
        self.announcements = [
            Announcement(
                id: UUID(),
                groopId: runGroop.id,
                title: "Canal Loop Session",
                body: "Meet by Castlefield Bowl at 7:00 AM for the 6K loop.",
                createdAt: .now.addingTimeInterval(-10_000)
            ),
            Announcement(
                id: UUID(),
                groopId: readingGroop.id,
                title: "Next Read Confirmed",
                body: "This month we picked The Bees by Laline Paull.",
                createdAt: .now.addingTimeInterval(-20_000)
            ),
            Announcement(
                id: UUID(),
                groopId: runGroop.id,
                title: "Heaton Park Warmup",
                body: "Sunday pace groups start at 8:30 AM near the lake cafe.",
                createdAt: .now.addingTimeInterval(-4_000)
            ),
            Announcement(
                id: UUID(),
                groopId: campfieldGroop.id,
                title: "Campfield Launch Session",
                body: "Friday cowork and introductions from 9:30 AM at Campfield.",
                createdAt: .now.addingTimeInterval(-2_500)
            )
        ]

        self.messages = [
            GroopMessage(
                id: UUID(),
                groopId: runGroop.id,
                senderName: "Maya",
                body: "Anyone up for a canal loop before work?",
                createdAt: .now.addingTimeInterval(-7_000),
                isFromCurrentUser: false
            ),
            GroopMessage(
                id: UUID(),
                groopId: runGroop.id,
                senderName: "Taylor",
                body: "Yes, I can do 7:00 AM from Castlefield.",
                createdAt: .now.addingTimeInterval(-6_700),
                isFromCurrentUser: true
            ),
            GroopMessage(
                id: UUID(),
                groopId: readingGroop.id,
                senderName: "Sam",
                body: "Shall we meet at Ancoats Coffee Co this Thursday?",
                createdAt: .now.addingTimeInterval(-8_500),
                isFromCurrentUser: false
            ),
            GroopMessage(
                id: UUID(),
                groopId: campfieldGroop.id,
                senderName: "Priya",
                body: "Anyone working from Campfield tomorrow afternoon?",
                createdAt: .now.addingTimeInterval(-4_200),
                isFromCurrentUser: false
            ),
            GroopMessage(
                id: UUID(),
                groopId: campfieldGroop.id,
                senderName: "Taylor",
                body: "Yes, I am there from 1 PM. Happy to pair on product strategy.",
                createdAt: .now.addingTimeInterval(-3_900),
                isFromCurrentUser: true
            )
        ]

        self.members = [
            GroopMember(id: UUID(), groopId: runGroop.id, name: "Alberto Hernandez", jobTitle: "Running Coach", status: "Host", isHost: true),
            GroopMember(id: UUID(), groopId: runGroop.id, name: "Maya Khan", jobTitle: "UX Designer", status: "Ready for Sunday pace group", isHost: false),
            GroopMember(id: UUID(), groopId: runGroop.id, name: "Liam Parker", jobTitle: "iOS Engineer", status: "Can do 6K this week", isHost: false),
            GroopMember(id: UUID(), groopId: runGroop.id, name: "Aisha Malik", jobTitle: "Marketing Lead", status: "Joining from Salford", isHost: false),
            GroopMember(id: UUID(), groopId: runGroop.id, name: "Tom Wright", jobTitle: "Data Analyst", status: "Trail run planned", isHost: false),
            GroopMember(id: UUID(), groopId: runGroop.id, name: "Nia Roberts", jobTitle: "Product Manager", status: "New to the groop", isHost: false),
            GroopMember(id: UUID(), groopId: readingGroop.id, name: "Andre Lorico", jobTitle: "Community Host", status: "Host", isHost: true),
            GroopMember(id: UUID(), groopId: readingGroop.id, name: "Jenica Chong", jobTitle: "Frontend Engineer", status: "I am in!", isHost: false),
            GroopMember(id: UUID(), groopId: readingGroop.id, name: "Elton Lin", jobTitle: "Researcher", status: "Loved chapter three", isHost: false),
            GroopMember(id: UUID(), groopId: readingGroop.id, name: "Anthony Wu", jobTitle: "Growth Consultant", status: "Will be there Thursday", isHost: false),
            GroopMember(id: UUID(), groopId: campfieldGroop.id, name: "Sarah O'Connell", jobTitle: "Startup Founder", status: "Host", isHost: true),
            GroopMember(id: UUID(), groopId: campfieldGroop.id, name: "Yusuf Ali", jobTitle: "iOS Developer", status: "Open to pair coding", isHost: false),
            GroopMember(id: UUID(), groopId: campfieldGroop.id, name: "Emily Hart", jobTitle: "Product Designer", status: "Happy to review portfolios", isHost: false),
            GroopMember(id: UUID(), groopId: campfieldGroop.id, name: "Ben Carter", jobTitle: "Data Scientist", status: "Exploring AI side projects", isHost: false),
            GroopMember(id: UUID(), groopId: campfieldGroop.id, name: "Harriet Jones", jobTitle: "Marketing Strategist", status: "Looking for collaborators", isHost: false)
        ]
    }

    func fetchMyGroops() async -> [Groop] {
        await apiClient.simulateLatency()
        return groops.filter(\.isJoined).sorted { $0.name < $1.name }
    }

    func fetchDiscoveryGroops() async -> [Groop] {
        await apiClient.simulateLatency()
        return groops.filter { !$0.isJoined }.sorted { $0.memberCount > $1.memberCount }
    }

    func groop(id: UUID) async -> Groop? {
        await apiClient.simulateLatency()
        return groops.first { $0.id == id }
    }

    func announcement(id: UUID) async -> Announcement? {
        await apiClient.simulateLatency()
        return announcements.first { $0.id == id }
    }

    func fetchAnnouncements(for groopId: UUID) async -> [Announcement] {
        await apiClient.simulateLatency()
        return announcements
            .filter { $0.groopId == groopId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func createAnnouncement(groopId: UUID, title: String, body: String) async -> Announcement {
        await apiClient.simulateLatency()

        let announcement = Announcement(
            id: UUID(),
            groopId: groopId,
            title: title,
            body: body,
            createdAt: .now
        )
        announcements.append(announcement)
        return announcement
    }

    func fetchMessages(for groopId: UUID) async -> [GroopMessage] {
        await apiClient.simulateLatency()
        return messages
            .filter { $0.groopId == groopId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func sendMessage(groopId: UUID, body: String, senderName: String, isFromCurrentUser: Bool) async -> GroopMessage {
        await apiClient.simulateLatency()
        let message = GroopMessage(
            id: UUID(),
            groopId: groopId,
            senderName: senderName,
            body: body,
            createdAt: .now,
            isFromCurrentUser: isFromCurrentUser
        )
        messages.append(message)
        return message
    }

    func fetchMembers(for groopId: UUID) async -> [GroopMember] {
        await apiClient.simulateLatency()
        return members.filter { $0.groopId == groopId }
    }

    func joinGroop(id: UUID) async {
        await apiClient.simulateLatency()
        guard let index = groops.firstIndex(where: { $0.id == id }) else { return }
        guard !groops[index].isJoined else { return }
        groops[index].isJoined = true
        groops[index].memberCount += 1
    }

    func createGroop(name: String, category: String, location: String, hostName: String) async -> Groop {
        await apiClient.simulateLatency()

        let newGroop = Groop(
            id: UUID(),
            name: name,
            category: category,
            location: location,
            memberCount: 1,
            isJoined: true
        )
        groops.append(newGroop)

        let host = GroopMember(
            id: UUID(),
            groopId: newGroop.id,
            name: hostName,
            jobTitle: "Community Host",
            status: "Host",
            isHost: true
        )
        members.append(host)

        let introAnnouncement = Announcement(
            id: UUID(),
            groopId: newGroop.id,
            title: "Welcome to \(name)",
            body: "This groop was just created. Share your first update and invite collaborators.",
            createdAt: .now
        )
        announcements.append(introAnnouncement)

        return newGroop
    }

    func feedItems(for groopId: UUID) async -> [FeedItem] {
        await apiClient.simulateLatency()
        guard let groop = groops.first(where: { $0.id == groopId }) else { return [] }

        return [
            FeedItem(
                id: UUID(),
                groopId: groopId,
                message: "\(groop.memberCount) members checked in across North West meetups this week.",
                timestamp: .now.addingTimeInterval(-3_600)
            ),
            FeedItem(
                id: UUID(),
                groopId: groopId,
                message: "New meetup spots are being suggested around \(groop.location).",
                timestamp: .now.addingTimeInterval(-7_200)
            )
        ]
    }
}
