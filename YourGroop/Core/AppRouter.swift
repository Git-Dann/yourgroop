import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    var path: [AppRoute] = []

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func openGroop(id: UUID) {
        path.append(.groopDetail(id))
    }
}

enum AppRoute: Hashable {
    case groopDetail(UUID)
    case groopChat(UUID, prefill: String?)
    case groopMembers(UUID)
    case announcementDetail(groopId: UUID, announcementId: UUID)
}

enum DeepLinkParser {
    static func route(from url: URL) -> AppRoute? {
        guard url.scheme == "yourgroop" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }

        if url.host == "groop", let first = parts.first, let id = UUID(uuidString: first) {
            return .groopDetail(id)
        }

        return nil
    }
}
