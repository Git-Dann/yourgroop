import Foundation

protocol APIClient: Sendable {
    func simulateLatency() async
}
