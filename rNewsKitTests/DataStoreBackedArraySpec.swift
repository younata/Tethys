import Quick
import Nimble
import CoreData
@testable import rNewsKit

class DataStoreBackedArraySpec: QuickSpec {
    override func spec() {
        var moc: NSManagedObjectContext! = nil
        var subject: DataStoreBackedArray<Article>! = nil

        var articles: [CoreDataArticle] = []

        let totalObjectCount = 35

        let batchSize = 20

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

            subject = DataStoreBackedArray(entityName: "Article", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: {
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

            let emptyArray = DataStoreBackedArray<Feed>(entityName: "Feed", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: { Feed(coreDataFeed: $0 as! CoreDataFeed) })
            expect(emptyArray.isEmpty) == true
        }

        it("should correctly return the first object") {
            expect(subject.first) == Article(coreDataArticle: articles[0], feed: nil)

            let emptyArray = DataStoreBackedArray<Feed>(entityName: "Feed", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: { Feed(coreDataFeed: $0 as! CoreDataFeed) })
            expect(emptyArray.first).to(beNil())
        }

        it("should not load anything until it's accessed") {
            expect(subject.internalObjects.isEmpty) == true
            expect(subject[0]) == Article(coreDataArticle: articles[0], feed: nil)

            expect(subject.internalObjects.isEmpty) == false
            let expectedArticles = Array(articles[0..<batchSize]).map { Article(coreDataArticle: $0, feed: nil) }
            expect(subject.internalObjects) == expectedArticles
        }

        it("should load successively more things") {
            expect(subject[26]) == Article(coreDataArticle: articles[26], feed: nil)
            expect(subject.internalObjects) == articles.map({Article(coreDataArticle: $0, feed: nil)})
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
            let shouldEqual = DataStoreBackedArray(entityName: "Article", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: {
                return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
            }, sortDescriptors: [sortDescriptor])
            expect(shouldEqual == subject) == true

            let entityNameOff = DataStoreBackedArray(entityName: "Feed", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: {
                return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
                }, sortDescriptors: [sortDescriptor])
            expect(subject == entityNameOff) != true

            let predicateOff = DataStoreBackedArray(entityName: "Article", predicate: NSPredicate(value: false), managedObjectContext: moc, conversionFunction: {
                return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
            }, sortDescriptors: [sortDescriptor])
            expect(predicateOff == subject) != true

            let managedObjectContextOff = DataStoreBackedArray(entityName: "Article", predicate: NSPredicate(value: true), managedObjectContext: managedObjectContext(), conversionFunction: {
                return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
            }, sortDescriptors: [sortDescriptor])
            expect(managedObjectContextOff == subject) != true

            let sortDescriptorOff = DataStoreBackedArray(entityName: "Article", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: {
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
            let article = Article(title: "025", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])

            subject.append(article)

            expect(subject.count) == 36

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

            let a = DataStoreBackedArray(entityName: "Article", predicate: NSPredicate(format: "title == %@", "002"), managedObjectContext: moc, conversionFunction: {
                return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
            }, sortDescriptors: [sortDescriptor])

            let b = DataStoreBackedArray(entityName: "Article", predicate: NSPredicate(format: "title == %@", "003"), managedObjectContext: moc, conversionFunction: {
                return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
            }, sortDescriptors: [sortDescriptor])

            let articles = articles.map({ Article(coreDataArticle: $0, feed: nil) })

            expect(Array(a.combine(b))) == [articles[2], articles[3]]
        }

        it("should allow itself to be combined with other predicates") {
            let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)

            let a = DataStoreBackedArray(entityName: "Article", predicate: NSPredicate(format: "title == %@", "003"), managedObjectContext: moc, conversionFunction: {
                return Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil)
                }, sortDescriptors: [sortDescriptor])

            let predicate = NSPredicate(format: "title == %@", "002")

            let articles = articles.map({ Article(coreDataArticle: $0, feed: nil) })

            expect(Array(a.combineWithPredicate(predicate))) == [articles[2], articles[3]]
        }

        it("should allow an object to be removed from it") {
            let articles = articles.map({ Article(coreDataArticle: $0, feed: nil) })
            let toRemove = articles[4]

            expect(subject.remove(toRemove)) == true
            expect(subject.count) == 34

            let expectedArticles = articles.filter { $0.title != toRemove.title }
            expect(Array(subject)) == expectedArticles

            let article = Article(title: "025", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
            subject.append(article)
            expect(subject.count) == 35
            expect(subject.remove(article)) == true
            expect(Array(subject)) == expectedArticles

            let queryList = DataStoreBackedArray(articles)
            expect(queryList.remove(toRemove)) == true
            expect(Array(queryList)) == expectedArticles
        }
    }
}
