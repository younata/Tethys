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
            realm.refresh()
            return realm
        }

        let realm: Realm
        do {
            realm = try Realm(configuration: self.configuration)
        } catch let error {
            fatalError("Received \(error) trying to create a realm")
        }
        self.realmsForThreads[thread] = realm

        realm.refresh()

        return realm
    }
}
