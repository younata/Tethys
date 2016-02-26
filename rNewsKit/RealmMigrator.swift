import RealmSwift

struct RealmMigrator {
    static func beginMigration() {
        Realm.Configuration.defaultConfiguration = Realm.Configuration(
            schemaVersion: 0,
            migrationBlock: self.realmMigration
        )
    }

    static func realmMigration(migration: Migration, oldSchemaVersion: UInt64) {

    }
}