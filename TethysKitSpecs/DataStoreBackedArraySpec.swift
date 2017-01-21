import Quick
import Nimble
import RealmSwift
@testable import TethysKit

class DataStoreBackedArraySpec: QuickSpec {
    override func spec() {
        var subject: DataStoreBackedArray<Article>! = nil
        let totalObjectCount = 125
        let batchSize = 50

        describe("a Realm backed array") {
            var realm: Realm!
            var articles: [RealmArticle] = []
            let realmConf = Realm.Configuration(inMemoryIdentifier: "DataStoreBackedArraySpec")

            beforeEach {
                realm = try! Realm(configuration: realmConf)
                try! realm.write {
                    realm.deleteAll()
                }

                articles = []

                realm.beginWrite()
                for i in 0..<totalObjectCount {
                    let article = realm.create(RealmArticle.self)
                    article.title = String(format: "%03d", i)
                    article.link = "https://example.com/article\(i)"
                    articles.append(article)
                    realm.add(article)
                }
                try! realm.commitWrite()

                let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)

                subject = DataStoreBackedArray(realmDataType: RealmArticle.self, predicate: NSPredicate(value: true), realmConfiguration: realmConf, conversionFunction: {
                    return Article(realmArticle: $0 as! RealmArticle, feed: nil)
                }, sortDescriptors: [sortDescriptor])
            }

            it("should correctly report the total number of objects it has") {
                expect(subject.count) == totalObjectCount
            }

            it("should implement isEmpty correctly") {
                expect(subject.isEmpty) == false

                let emptyArray = DataStoreBackedArray<Feed>(realmDataType: RealmFeed.self, predicate: NSPredicate(value: true), realmConfiguration: realmConf, conversionFunction: { Feed(realmFeed: $0 as! RealmFeed) })
                expect(emptyArray.isEmpty) == true
            }

            it("should correctly return the first object") {
                expect(subject.first) == Article(realmArticle: articles[0], feed: nil)

                let emptyArray = DataStoreBackedArray<Feed>(realmDataType: RealmFeed.self, predicate: NSPredicate(value: true), realmConfiguration: realmConf, conversionFunction: { Feed(realmFeed: $0 as! RealmFeed) })
                expect(emptyArray.first).to(beNil())
            }

            it("should not load anything until it's accessed") {
                expect(subject.internalObjects.isEmpty) == true
                expect(subject[0]) == Article(realmArticle: articles[0], feed: nil)

                expect(subject.internalObjects.isEmpty) == false
                let expectedArticles = Array(articles[0..<batchSize]).map { Article(realmArticle: $0, feed: nil) }
                expect(subject.internalObjects) == expectedArticles
            }

            it("should load successively more things") {
                expect(subject[batchSize + 5]) == Article(realmArticle: articles[batchSize + 5], feed: nil)
                expect(subject.internalObjects.count) == batchSize * 2
            }

            it("should be iterable") {
                let expectedArticles = articles.map { Article(realmArticle: $0, feed: nil) }

                for (idx, article) in subject.enumerated() {
                    if idx >= expectedArticles.count {
                        expect(subject.count) == expectedArticles.count
                        return
                    }
                    expect(article) == expectedArticles[idx]
                }
            }

            it("should allow an Array to be created from it") {
                let expectedArticles = articles.map { Article(realmArticle: $0, feed: nil) }
                expect(Array(subject)) == expectedArticles
            }

            it("should be equatable") {
                let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
                let shouldEqual = DataStoreBackedArray(realmDataType: RealmArticle.self, predicate: NSPredicate(value: true), realmConfiguration: realmConf, conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) }, sortDescriptors: [sortDescriptor])
                expect(shouldEqual == subject) == true

                let entityNameOff = DataStoreBackedArray(realmDataType: RealmFeed.self, predicate: NSPredicate(value: true), realmConfiguration: realmConf, conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) }, sortDescriptors: [sortDescriptor])
                expect(subject == entityNameOff) != true

                let predicateOff = DataStoreBackedArray(realmDataType: RealmArticle.self, predicate: NSPredicate(value: false), realmConfiguration: realmConf, conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) }, sortDescriptors: [sortDescriptor])
                expect(predicateOff == subject) != true

                let otherRealmConfiguration = Realm.Configuration(inMemoryIdentifier: "DataStoreBackedArraySpec2")

                let realmOff = DataStoreBackedArray(realmDataType: RealmArticle.self, predicate: NSPredicate(value: true), realmConfiguration: otherRealmConfiguration, conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) }, sortDescriptors: [sortDescriptor])
                expect(realmOff == subject) != true

                let sortDescriptorOff = DataStoreBackedArray(realmDataType: RealmArticle.self, predicate: NSPredicate(value: true), realmConfiguration: realmConf, conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) }, sortDescriptors: [])
                expect(sortDescriptorOff == subject) != true

                let expectedArticles = articles.map { Article(realmArticle: $0, feed: nil) }
                let object = DataStoreBackedArray(expectedArticles)
                expect(object == subject) == true
            }

            it("should allow itself to be created with an array backing it, for testing reasons") {
                let expectedArticles = articles.map { Article(realmArticle: $0, feed: nil) }

                let object = DataStoreBackedArray(expectedArticles)
                expect(Array(object)) == expectedArticles
            }

            it("should allow itself to be appended to") {
                let article = Article(title: "025", link: URL(string: "https://example.com/article25")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])

                subject.append(article)

                expect(subject.count) == totalObjectCount + 1

                let expectedArticles = articles.map { Article(realmArticle: $0, feed: nil) }
                expect(Array(subject)) == expectedArticles + [article]

                let queryList = DataStoreBackedArray(expectedArticles)
                queryList.append(article)
                expect(Array(queryList)) == expectedArticles + [article]
            }

            it("should work well with filter") {
                let results = subject.filter { $0.title == "001" }
                expect(results) == [Article(realmArticle: articles[1], feed: nil)]
            }

            it("should allow a filter with a predicate") {
                let results = subject.filterWithPredicate(NSPredicate(format: "title == %@", "001"))
                expect(Array(results)) == [Article(realmArticle: articles[1], feed: nil)]
            }

            it("should allow itself to be combined with another DataStoreBackedArray easily") {
                expect(Array(subject.combine(subject))) == Array(subject) // simple case

                let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)

                let a = DataStoreBackedArray(realmDataType: RealmArticle.self, predicate: NSPredicate(format: "title == %@", "002"), realmConfiguration: realmConf, conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) }, sortDescriptors: [sortDescriptor])
                let b = DataStoreBackedArray(realmDataType: RealmArticle.self, predicate: NSPredicate(format: "title == %@", "003"), realmConfiguration: realmConf, conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) }, sortDescriptors: [sortDescriptor])

                let articles = articles.map({ Article(realmArticle: $0, feed: nil) })

                expect(Array(a.combine(b))) == [articles[2], articles[3]]
            }

            it("should allow an object to be removed from it") {
                let articles = articles.map({ Article(realmArticle: $0, feed: nil) })
                let toRemove = articles[4]

                expect(subject.remove(toRemove).wait()) == true
                expect(subject.count) == totalObjectCount - 1

                let expectedArticles = articles.filter { $0.title != toRemove.title }
                expect(Array(subject)) == expectedArticles

                let article = Article(title: "025", link: URL(string: "https://example.com/article25")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])
                subject.append(article)
                expect(subject.count) == totalObjectCount
                expect(subject.remove(article).wait()) == true
                expect(Array(subject)) == expectedArticles

                let queryList = DataStoreBackedArray(articles)
                expect(queryList.remove(toRemove).wait()) == true
                expect(Array(queryList)) == expectedArticles
            }
        }
    }
}
