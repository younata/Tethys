import RealmSwift

struct RealmMigrator {
    static func beginMigration() {
        if NSUserDefaults.standardUserDefaults().boolForKey("FASTLANE_SNAPSHOT") {
            Realm.Configuration.defaultConfiguration = Realm.Configuration(path: nil,
                inMemoryIdentifier: "SnapShot",
                schemaVersion: 0,
                migrationBlock: self.realmMigration
            )
        } else {
            Realm.Configuration.defaultConfiguration = Realm.Configuration(
                schemaVersion: 0,
                migrationBlock: self.realmMigration
            )
        }
    }

    static func realmMigration(migration: Migration, oldSchemaVersion: UInt64) {

    }
}
