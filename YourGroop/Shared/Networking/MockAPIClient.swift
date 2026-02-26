import Foundation

struct MockAPIClient: APIClient {
    let latencyNanoseconds: UInt64

    init(latencyNanoseconds: UInt64 = 250_000_000) {
        self.latencyNanoseconds = latencyNanoseconds
    }

    func simulateLatency() async {
        try? await Task.sleep(nanoseconds: latencyNanoseconds)
    }
}
