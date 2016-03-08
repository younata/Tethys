import RealmSwift

struct RealmMigrator {
    static func beginMigration() {
        let schemaVersion: UInt64 = 0
        if NSUserDefaults.standardUserDefaults().boolForKey("FASTLANE_SNAPSHOT") {
            Realm.Configuration.defaultConfiguration = Realm.Configuration(
                inMemoryIdentifier: "SnapShot",
                schemaVersion: schemaVersion,
                migrationBlock: self.realmMigration
            )
        } else {
            Realm.Configuration.defaultConfiguration = Realm.Configuration(
                schemaVersion: schemaVersion,
                migrationBlock: self.realmMigration
            )
        }
    }

    static func realmMigration(migration: Migration, oldSchemaVersion: UInt64) {
    }
}
