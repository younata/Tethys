import RealmSwift

struct RealmMigrator {
    static func beginMigration() {
        let schemaVersion: UInt64 = 15
        if UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT") {
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

    // swiftlint:disable cyclomatic_complexity
    static func realmMigration(_ migration: Migration, oldSchemaVersion: UInt64) {
        if oldSchemaVersion < 1 {
            migration.enumerateObjects(ofType: RealmArticle.className()) { oldObject, newObject in
                if let oldAuthor = oldObject?["author"] as? String {
                    let oldAuthors = oldAuthor.components(separatedBy: ", ")
                    let newAuthors: [MigrationObject] = oldAuthors.compactMap { oldAuthor in
                        let newAuthor = migration.create(RealmAuthor.className())
                        let (name, email) = self.nameAndEmailFromAuthorString(oldAuthor)
                        newAuthor["name"] = name
                        newAuthor["email"] = email
                        if name.isEmpty && email.isEmpty {
                            return nil
                        }
                        return newAuthor
                    }
                    newObject?["authors"] = newAuthors
                }
            }
        }
        if oldSchemaVersion < 2 {
            migration.deleteData(forType: "RealmEnclosure")
        }
        if oldSchemaVersion < 5 {
            migration.enumerateObjects(ofType: RealmFeed.className()) { oldObject, newObject in
                if let oldObject = oldObject, let newObject = newObject, oldObject["url"] == nil {
                        migration.delete(newObject)
                }
            }
        }
        if oldSchemaVersion < 10 {
            migration.enumerateObjects(ofType: RealmFeed.className()) { oldObject, newObject in
                if let newObject = newObject, let oldObject = oldObject {
                    guard let oldURLString = oldObject["url"] as? String? else {
                        migration.delete(newObject)
                        return
                    }
                    if let urlString = oldURLString {
                        newObject["url"] = urlString
                    } else {
                        migration.delete(newObject)
                    }
                }
            }
        }
        if oldSchemaVersion < 15 {
            migration.enumerateObjects(ofType: RealmFeed.className()) { oldObject, _ in
                oldObject?["_source"] = "local"
            }
        }
    }
    // swiftlint:enable=cyclomatic_complexity

    static func nameAndEmailFromAuthorString(_ author: String) -> (name: String, email: String) {
        let author = author.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let components = author.components(separatedBy: " ")
        if components.count == 0 { return ("", "") }
        let bracketCharacterSet = CharacterSet(charactersIn: "<>")

        if components.count == 1 {
            let string = components[0]
            if string.hasPrefix("<") && string.hasSuffix(">") {
                return ("", string.trimmingCharacters(in: bracketCharacterSet))
            } else {
                return (string, "")
            }
        }
        let nameComponents = components[0..<(components.count - 1)]
        let name = nameComponents.joined(separator: " ")
        return (name, components.last!.trimmingCharacters(in: bracketCharacterSet))
    }
}
