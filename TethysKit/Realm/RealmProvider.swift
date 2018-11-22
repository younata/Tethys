import RealmSwift

protocol RealmProvider {
    func realm() -> Realm
}

final class DefaultRealmProvider: RealmProvider {
    private let configuration: Realm.Configuration

    init(configuration: Realm.Configuration) {
        self.configuration = configuration
    }

    private var realmsForThreads: [Thread: Realm] = [:]

    func realm() -> Realm {
        let thread = Thread.current
        if let realm = self.realmsForThreads[thread] {
            return realm
        }

        // swiftlint:disable force_try
        let realm = try! Realm(configuration: self.configuration)
        // swiftlint:enable force_try
        self.realmsForThreads[thread] = realm

        return realm
    }
}
