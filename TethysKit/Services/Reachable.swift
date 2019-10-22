import Reachability

protocol Reachable {
    var hasNetworkConnectivity: Bool { get }
}

extension Reachability: Reachable {
    var hasNetworkConnectivity: Bool {
        return self.connection != .unavailable
    }
}
