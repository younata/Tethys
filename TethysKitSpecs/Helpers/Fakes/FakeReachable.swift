@testable import TethysKit

class FakeReachable: Reachable {
    var hasNetworkConnectivity: Bool

    init(hasNetworkConnectivity: Bool) {
        self.hasNetworkConnectivity = hasNetworkConnectivity
    }
}
