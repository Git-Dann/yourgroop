import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    struct Session: Equatable {
        let displayName: String
    }

    var session: Session?
    var isLoading = false
    var myGroops: [Groop] = []
    var discoveryGroops: [Groop] = []
    var errorMessage: String?

    let repository: any GroopRepository

    init(repository: any GroopRepository) {
        self.repository = repository
    }

    var isSignedIn: Bool {
        session != nil
    }

    func bootstrap(autoSignIn: Bool) async {
        if autoSignIn, session == nil {
            session = Session(displayName: "UI Test User")
        }

        guard isSignedIn else { return }
        await refreshAll()
    }

    func signIn() async {
        isLoading = true
        defer { isLoading = false }

        try? await Task.sleep(nanoseconds: 350_000_000)
        session = Session(displayName: "Taylor")
        await refreshAll()
    }

    func refreshAll() async {
        isLoading = true
        defer { isLoading = false }

        myGroops = await repository.fetchMyGroops()
        discoveryGroops = await repository.fetchDiscoveryGroops()
    }

    func joinGroop(id: UUID) async {
        await repository.joinGroop(id: id)
        await refreshAll()
    }

    func createGroop(name: String, category: String, location: String) async {
        let host = session?.displayName ?? "You"
        _ = await repository.createGroop(name: name, category: category, location: location, hostName: host)
        await refreshAll()
    }
}
