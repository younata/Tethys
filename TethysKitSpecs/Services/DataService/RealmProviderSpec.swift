import Quick
import Nimble
import RealmSwift

@testable import TethysKit

final class RealmProviderSpec: QuickSpec {
    override func spec() {
        var subject: RealmProvider!

        let realmConf = Realm.Configuration(inMemoryIdentifier: "RealmServiceSpec")

        beforeEach {
            subject = DefaultRealmProvider(
                configuration: realmConf
            )
        }

        describe("realm()") {
            it("returns a realm") {
                expect(subject.realm()).toNot(beNil())
            }

            it("returns a realm when asked for in a separate thread") {
                var realm: Realm?

                OperationQueue().addOperation {
                    realm = subject.realm()
                }

                expect(realm).toEventuallyNot(beNil())
            }
        }
    }
}
