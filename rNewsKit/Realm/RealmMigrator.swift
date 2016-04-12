import RealmSwift

struct RealmMigrator {
    static func beginMigration() {
        let schemaVersion: UInt64 = 1
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

    static func realmMigration(migration: Migration, schemaVersion: UInt64) {
        migration.enumerate(RealmArticle.className()) { oldObject, newObject in
            if schemaVersion < 1 {
                if let oldAuthor = oldObject?["author"] as? String {
                    let oldAuthors = oldAuthor.componentsSeparatedByString(", ")
                    let newAuthors: [MigrationObject] = oldAuthors.flatMap { oldAuthor in
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
    }

    static func nameAndEmailFromAuthorString(author: String) -> (name: String, email: String) {
        let author = author.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        let components = author.componentsSeparatedByString(" ")
        if components.count == 0 { return ("", "") }
        let bracketCharacterSet = NSCharacterSet(charactersInString: "<>")

        if components.count == 1 {
            let string = components[0]
            if string.hasPrefix("<") && string.hasSuffix(">") {
                return ("", string.stringByTrimmingCharactersInSet(bracketCharacterSet))
            } else {
                return (string, "")
            }
        }
        let nameComponents = components[0..<(components.count - 1)]
        let name = nameComponents.joinWithSeparator(" ")
        return (name, components.last!.stringByTrimmingCharactersInSet(bracketCharacterSet))
    }
}
