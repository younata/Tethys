@testable import rNewsKit

class FakeReachable: Reachable {
    var hasNetworkConnectivity: Bool

    init(hasNetworkConnectivity: Bool) {
        self.hasNetworkConnectivity = hasNetworkConnectivity
    }
}