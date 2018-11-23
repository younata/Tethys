public protocol Analytics {
    func logEvent(_ event: String, data: [String: String]?)
}

struct BadAnalytics: Analytics {
    func logEvent(_ event: String, data: [String: String]?) {
        // Drops the information on the floor
    }
}
