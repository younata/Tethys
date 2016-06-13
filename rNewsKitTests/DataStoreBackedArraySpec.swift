import Quick
import Nimble
import CoreData
import RealmSwift
@testable import rNewsKit

private func dataStoreBackedArray<T>(realmDataType realmDataType: Object.Type, predicate: NSPredicate, realmConfiguration: Realm.Configuration, conversionFunction: Object -> T, sortDescriptors: [NSSortDescriptor] = []) -> DataStoreBackedArray<T> {
    let sortDescriptors = sortDescriptors.map { SortDescriptor(property: $0.key!, ascending: $0.ascending) }

    let fetchResults = RealmFetchResultsController(configuration: realmConfiguration, model: realmDataType, sortDescriptors: sortDescriptors, predicate: predicate)

    return DataStoreBackedArray(realmFetchResultsController: fetchResults, conversionFunction: conversionFunction)
}

private func dataStoreBackedArray<T>(entityName entityName: String, predicate: NSPredicate, managedObjectContext: NSManagedObjectContext, conversionFunction: NSManagedObject -> T, sortDescriptors: [NSSortDescriptor] = []) -> DataStoreBackedArray<T> {
    let fetchResults = CoreDataFetchResultsController(entityName: entityName, managedObjectContext: managedObjectContext, sortDescriptors: sortDescriptors, predicate: predicate)
    return DataStoreBackedArray<T>(coreDataFetchResultsController: fetchResults, conversionFunction: conversionFunction)
}

class DataStoreBackedArraySpec: QuickSpec {
    override func spec() {
        var subject: DataStoreBackedArray<Article>! = nil
        let totalObjectCount = 125

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
                    let article = realm.create(RealmArticle)
                    article.title = String(format: "%03d", i)
                    articles.append(article)
                    realm.add(article)
                }
                try! realm.commitWrite()

                let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)

                subject = dataStoreBackedArray(realmDataType: RealmArticle.self, predicate: NSPredicate(value: true), realmConfiguration: realmConf, conversionFunction: {
                    return Article(realmArticle: $0 as! RealmArticle, feed: nil)
                }, sortDescriptors: [sortDescriptor])
            }

            it("should correctly report the total number of objects it has") {
                expect(subject.count) == totalObjectCount
            }

            it("should implement isEmpty correctly") {
                expect(subject.isEmpty) == false

                let emptyArray = dataStoreBackedArray(realmDataType: RealmFeed.self, predicate: NSPredicate(value: true), realmConfiguration: realmConf, conversionFunction: { Feed(realmFeed: $0 as! RealmFeed) })
                expect(emptyArray.isEmpty) == true
            }

            it("should correctly return the first object") {
                expect(subject.first) == Article(realmArticle: articles[0], feed: nil)

                let emptyArray = dataStoreBackedArray(realmDataType: RealmFeed.self, predicate: NSPredicate(value: true), realmConfiguration: realmConf, conversionFunction: { Feed(realmFeed: $0 as! RealmFeed) })
                expect(emptyArray.first).to(beNil())
            }

            it("should be iterable") {
                let expectedArticles = articles.map { Article(realmArticle: $0, feed: nil) }

                for (idx, article) in subject.enumerate() {
                    expect(article) == expectedArticles[idx]
                }
            }

            it("should allow an Array to be created from it") {
                let expectedArticles = articles.map { Article(realmArticle: $0, feed: nil) }
                expect(Array(subject)) == expectedArticles
            }

            it("should be equatable") {
                let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
                let shouldEqual = dataStoreBackedArray(realmDataType: RealmArticle.self, predicate: NSPredicate(value: true), realmConfiguration: realmConf, conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) }, sortDescriptors: [sortDescriptor])
                expect(shouldEqual == subject) == true

                let entityNameOff = dataStoreBackedArray(realmDataType: RealmFeed.self, predicate: NSPredicate(value: true), realmConfiguration: realmConf, conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) }, sortDescriptors: [sortDescriptor])
                expect(subject == entityNameOff) != true

                let predicateOff = dataStoreBackedArray(realmDataType: RealmArticle.self, predicate: NSPredicate(value: false), realmConfiguration: realmConf, conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) }, sortDescriptors: [sortDescriptor])
                expect(predicateOff == subject) != true

                let sortDescriptorOff = dataStoreBackedArray(realmDataType: RealmArticle.self, predicate: NSPredicate(value: true), realmConfiguration: realmConf, conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) }, sortDescriptors: [])
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
                let article = Article(title: "025", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])

                expect(subject.contains(article)) == false

                subject.append(article)

                expect(subject.count) == totalObjectCount + 1

                let expectedArticles = articles.map { Article(realmArticle: $0, feed: nil) }
                expect(subject.contains(article)) == true
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

                let a = dataStoreBackedArray(realmDataType: RealmArticle.self, predicate: NSPredicate(format: "title == %@", "002"), realmConfiguration: realmConf, conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) }, sortDescriptors: [sortDescriptor])
                let b = dataStoreBackedArray(realmDataType: RealmArticle.self, predicate: NSPredicate(format: "title == %@", "003"), realmConfiguration: realmConf, conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) }, sortDescriptors: [sortDescriptor])

                let articles = articles.map({ Article(realmArticle: $0, feed: nil) })

                expect(Array(a.combine(b))) == [articles[2], articles[3]]
            }

            it("should allow an object to be removed from it") {
                let articles = articles.map({ Article(realmArticle: $0, feed: nil) })
                let toRemove = articles[4]

                expect(subject.count) == totalObjectCount

                expect(subject.remove(toRemove).wait()) == true
                expect(subject.count) == totalObjectCount - 1

                let expectedArticles = articles.filter { $0.title != toRemove.title }
                expect(Array(subject)) == expectedArticles

                let article = Article(title: "025", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
                subject.append(article)
                expect(subject.count) == totalObjectCount
                expect(subject.remove(article).wait()) == true
                expect(Array(subject)) == expectedArticles
                expect(subject.count) == totalObjectCount - 1

                let queryList = DataStoreBackedArray(articles)
                expect(queryList.remove(toRemove).wait()) == true
                expect(Array(queryList)) == expectedArticles
                expect(subject.count) == totalObjectCount - 1
            }
        }

        describe("A CoreData backed array") {
            var moc: NSManagedObjectContext! = nil
            var articles: [CoreDataArticle] = []

            beforeEach {
                moc = managedObjectContext()

                articles = []

                for i in 0..<totalObjectCount {
                    let article = createArticle(moc)
                    article.title = String(format: "%03d", i)
                    articles.append(article)
                }

                try! moc.save()

                let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)

                subject = dataStoreBackedArray(entityName: "Article", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: {
                    return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
                }, sortDescriptors: [sortDescriptor])
            }

            afterEach {
                articles = []
            }

            it("should correctly report the total number of objects it has") {
                expect(subject.count) == totalObjectCount
            }

            it("should implement isEmpty correctly") {
                expect(subject.isEmpty) == false

                let emptyArray = dataStoreBackedArray(entityName: "Feed", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: { Feed(coreDataFeed: $0 as! CoreDataFeed) })
                expect(emptyArray.isEmpty) == true
            }

            it("should correctly return the first object") {
                expect(subject.first) == Article(coreDataArticle: articles[0], feed: nil)

                let emptyArray = dataStoreBackedArray(entityName: "Feed", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: { Feed(coreDataFeed: $0 as! CoreDataFeed) })
                expect(emptyArray.first).to(beNil())
            }

            it("should be iterable") {
                let expectedArticles = articles.map { Article(coreDataArticle: $0, feed: nil) }

                for (idx, article) in subject.enumerate() {
                    expect(article) == expectedArticles[idx]
                }
            }

            it("should allow an Array to be created from it") {
                let expectedArticles = articles.map { Article(coreDataArticle: $0, feed: nil) }
                expect(Array(subject)) == expectedArticles
            }

            it("should be equatable") {
                let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
                let shouldEqual = dataStoreBackedArray(entityName: "Article", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: {
                    return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
                    }, sortDescriptors: [sortDescriptor])
                expect(shouldEqual == subject) == true

                let entityNameOff = dataStoreBackedArray(entityName: "Feed", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: {
                    return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
                    }, sortDescriptors: [sortDescriptor])
                expect(subject == entityNameOff) != true

                let predicateOff = dataStoreBackedArray(entityName: "Article", predicate: NSPredicate(value: false), managedObjectContext: moc, conversionFunction: {
                    return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
                    }, sortDescriptors: [sortDescriptor])
                expect(predicateOff == subject) != true

                let managedObjectContextOff = dataStoreBackedArray(entityName: "Article", predicate: NSPredicate(value: true), managedObjectContext: managedObjectContext(), conversionFunction: {
                    return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
                    }, sortDescriptors: [sortDescriptor])
                expect(managedObjectContextOff == subject) != true

                let sortDescriptorOff = dataStoreBackedArray(entityName: "Article", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: {
                    return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
                    }, sortDescriptors: [])
                expect(sortDescriptorOff == subject) != true

                let expectedArticles = articles.map { Article(coreDataArticle: $0, feed: nil) }
                let object = DataStoreBackedArray(expectedArticles)
                expect(object == subject) == true
            }

            it("should allow itself to be created with an array backing it, for testing reasons") {
                let expectedArticles = articles.map { Article(coreDataArticle: $0, feed: nil) }

                let object = DataStoreBackedArray(expectedArticles)
                expect(Array(object)) == expectedArticles
            }

            it("should allow itself to be appended to") {
                let article = Article(title: "025", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])

                subject.append(article)

                expect(subject.count) == totalObjectCount + 1

                let expectedArticles = articles.map { Article(coreDataArticle: $0, feed: nil) }
                expect(Array(subject)) == expectedArticles + [article]

                let queryList = DataStoreBackedArray(expectedArticles)
                queryList.append(article)
                expect(Array(queryList)) == expectedArticles + [article]
            }

            it("should work well with filter") {
                let results = subject.filter { $0.title == "001" }
                expect(results) == [Article(coreDataArticle: articles[1], feed: nil)]
            }

            it("should allow a filter with a predicate") {
                let results = subject.filterWithPredicate(NSPredicate(format: "title == %@", "001"))
                expect(Array(results)) == [Article(coreDataArticle: articles[1], feed: nil)]
            }

            it("should allow itself to be combined with another DataStoreBackedArray easily") {
                expect(Array(subject.combine(subject))) == Array(subject) // simple case

                let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)

                let a = dataStoreBackedArray(entityName: "Article", predicate: NSPredicate(format: "title == %@", "002"), managedObjectContext: moc, conversionFunction: {
                    return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
                    }, sortDescriptors: [sortDescriptor])

                let b = dataStoreBackedArray(entityName: "Article", predicate: NSPredicate(format: "title == %@", "003"), managedObjectContext: moc, conversionFunction: {
                    return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
                    }, sortDescriptors: [sortDescriptor])

                let articles = articles.map({ Article(coreDataArticle: $0, feed: nil) })

                expect(Array(a.combine(b))) == [articles[2], articles[3]]
            }

            it("should allow an object to be removed from it") {
                let articles = articles.map({ Article(coreDataArticle: $0, feed: nil) })
                let toRemove = articles[4]

                expect(subject.remove(toRemove).wait()) == true
                expect(subject.count) == totalObjectCount - 1

                let expectedArticles = articles.filter { $0.title != toRemove.title }
                expect(Array(subject)) == expectedArticles

                let article = Article(title: "025", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
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
