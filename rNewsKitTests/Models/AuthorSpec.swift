import Quick
import Nimble
import RealmSwift
@testable import rNewsKit

class AuthorSpec: QuickSpec {
    override func spec() {
        var subject: Author! = nil
        var realm: Realm!

        beforeEach {
            let realmConf = Realm.Configuration(inMemoryIdentifier: "AuthorSpec")
            realm = try! Realm(configuration: realmConf)
            try! realm.write {
                realm.deleteAll()
            }

            subject = Author(name: "test", email: NSURL(string: "foo@example.com"))
        }
    }
}
