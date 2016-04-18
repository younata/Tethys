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

        describe("description") {
            it("formats authors with emails available as 'Foo <foo@example.com>'") {
                expect(subject.description) == "test <foo@example.com>"
            }

            it("does not include the <email@domain> if email is nil") {
                let author = Author(name: "example", email: nil)
                expect(author.description) == "example"
            }

            it("does not include the '<>' if email is empty but non-nil") {
                let author = Author(name: "Rachel", email: NSURL(string: ""))
                expect(author.description) == "Rachel"
            }
        }
    }
}
