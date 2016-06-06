import Quick
import Nimble
import RealmSwift
@testable import rNewsKit

class RealmFetchResultsControllerSpec: QuickSpec {
    override func spec() {
        describe("RealmFetchResultsController") {
            var subject: RealmFetchResultsController<RealmArticle>!
            var realm: Realm!
            var objects: [RealmArticle] = []
            let realmConf = Realm.Configuration(inMemoryIdentifier: "DataStoreBackedArraySpec")

            let totalObjectCount = 200

            beforeEach {
                realm = try! Realm(configuration: realmConf)
                try! realm.write {
                    realm.deleteAll()
                }

                objects = []

                realm.beginWrite()
                for i in 0..<totalObjectCount {
                    let article = realm.create(RealmArticle)
                    article.title = String(format: "%03d", i)
                    objects.append(article)
                    realm.add(article)
                }
                try! realm.commitWrite()

                subject = RealmFetchResultsController(configuration: realmConf, sortDescriptors: [], predicate: NSPredicate(value: true))
            }

            it("gets the count correctly") {
                expect(subject.count) == totalObjectCount
            }

            it("gets an item from the list") {
                for (idx, object) in objects.enumerate() {
                    expect{ try? subject.get(idx) }.to(equal(object))
                    expect(subject[idx]) == object
                }
            }

            it("throws an error if you get an object outside the range") {
                expect { try subject.get(-1) }.to(throwError())
                expect { try subject.get(totalObjectCount) }.to(throwError())
            }

            it("inserts an item into the realm when you call 'insert'") {
                let item = RealmArticle()
                item.title = "Example"
                try! subject.insert(item)
                expect(subject.count) == totalObjectCount + 1
                expect(subject[totalObjectCount]) == item
                expect(realm.objects(RealmArticle)).to(contain(item))
            }
            
            it("deletes an item from the realm when you call 'delete'") {
                try! subject.delete(1)
                expect(subject.count) == totalObjectCount - 1
                expect(realm.objects(RealmArticle)).toNot(contain(objects[1]))
            }
        }
    }
}
