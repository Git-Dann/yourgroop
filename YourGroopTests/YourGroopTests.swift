import XCTest
@testable import YourGroop

@MainActor
final class YourGroopTests: XCTestCase {
    func testFetchMyGroopsReturnsJoinedOnly() async {
        let repository = InMemoryGroopRepository(apiClient: MockAPIClient(latencyNanoseconds: 0))

        let myGroops = await repository.fetchMyGroops()

        XCTAssertFalse(myGroops.isEmpty)
        XCTAssertTrue(myGroops.allSatisfy(\.isJoined))
    }

    func testCreateAnnouncementAppearsInMostRecentResults() async {
        let repository = InMemoryGroopRepository(apiClient: MockAPIClient(latencyNanoseconds: 0))
        let groop = (await repository.fetchMyGroops()).first
        XCTAssertNotNil(groop)

        guard let groop else { return }

        _ = await repository.createAnnouncement(groopId: groop.id, title: "Test Update", body: "Body")
        let announcements = await repository.fetchAnnouncements(for: groop.id)

        XCTAssertEqual(announcements.first?.title, "Test Update")
    }
}
