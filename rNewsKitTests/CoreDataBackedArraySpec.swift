import Quick
import Nimble
import CoreData
@testable import rNewsKit

extension Article: CustomDebugStringConvertible {
    override public var debugDescription: String {
        return "Title: \(self.title)"
    }
}

class CoreDataBackedArraySpec: QuickSpec {
    override func spec() {
        var moc: NSManagedObjectContext! = nil
        var subject: CoreDataBackedArray<Article>! = nil

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

            subject = CoreDataBackedArray(entityName: "Article", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: {
                return Article(article: $0 as! CoreDataArticle, feed: nil)
            }, sortDescriptors: [sortDescriptor])
        }

        afterEach {
            articles = []
        }

        it("should correctly report the total number of objects it has") {
            expect(subject.count).to(equal(totalObjectCount))
        }

        it("should implement isEmpty correctly") {
            expect(subject.isEmpty).to(beFalsy())

            let emptyArray = CoreDataBackedArray<Feed>(entityName: "Feed", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: { Feed(feed: $0 as! CoreDataFeed) })
            expect(emptyArray.isEmpty).to(beTruthy())
        }

        it("should correctly return the first object") {
            expect(subject.first).to(equal(Article(article: articles[0], feed: nil)))

            let emptyArray = CoreDataBackedArray<Feed>(entityName: "Feed", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: { Feed(feed: $0 as! CoreDataFeed) })
            expect(emptyArray.first).to(beNil())
        }

        it("should not load anything until it's accessed") {
            expect(subject.internalObjects.isEmpty).to(beTruthy())
            expect(subject[0]).to(equal(Article(article: articles[0], feed: nil)))

            expect(subject.internalObjects.isEmpty).to(beFalsy())
            let expectedArticles = Array(articles[0..<batchSize]).map { Article(article: $0, feed: nil) }
            expect(subject.internalObjects).to(equal(expectedArticles))
        }

        it("should load successively more things") {
            expect(subject[26]).to(equal(Article(article: articles[26], feed: nil)))
            expect(subject.internalObjects).to(equal(articles.map({Article(article: $0, feed: nil)})))
        }

        it("should be iterable") {
            let expectedArticles = articles.map { Article(article: $0, feed: nil) }

            for (idx, article) in subject.enumerate() {
                expect(article).to(equal(expectedArticles[idx]))
            }
        }

        it("should allow an Array to be created from it") {
            let expectedArticles = articles.map { Article(article: $0, feed: nil) }
            expect(Array(subject)).to(equal(expectedArticles))
        }

        it("should be equatable") {
            let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
            let shouldEqual = CoreDataBackedArray(entityName: "Article", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: {
                return Article(article: $0 as! CoreDataArticle, feed: nil)
            }, sortDescriptors: [sortDescriptor])
            expect(shouldEqual == subject).to(beTruthy())

            let entityNameOff = CoreDataBackedArray(entityName: "Feed", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: {
                return Article(article: $0 as! CoreDataArticle, feed: nil)
                }, sortDescriptors: [sortDescriptor])
            expect(subject == entityNameOff).toNot(beTruthy())

            let predicateOff = CoreDataBackedArray(entityName: "Article", predicate: NSPredicate(value: false), managedObjectContext: moc, conversionFunction: {
                return Article(article: $0 as! CoreDataArticle, feed: nil)
            }, sortDescriptors: [sortDescriptor])
            expect(predicateOff == subject).toNot(beTruthy())

            let managedObjectContextOff = CoreDataBackedArray(entityName: "Article", predicate: NSPredicate(value: true), managedObjectContext: managedObjectContext(), conversionFunction: {
                return Article(article: $0 as! CoreDataArticle, feed: nil)
            }, sortDescriptors: [sortDescriptor])
            expect(managedObjectContextOff == subject).toNot(beTruthy())

            let sortDescriptorOff = CoreDataBackedArray(entityName: "Article", predicate: NSPredicate(value: true), managedObjectContext: moc, conversionFunction: {
                return Article(article: $0 as! CoreDataArticle, feed: nil)
            }, sortDescriptors: [])
            expect(sortDescriptorOff == subject).toNot(beTruthy())

            let expectedArticles = articles.map { Article(article: $0, feed: nil) }
            let object = CoreDataBackedArray(expectedArticles)
            expect(object == subject).to(beTruthy())
        }

        it("should allow itself to be created with an array backing it, for testing reasons") {
            let expectedArticles = articles.map { Article(article: $0, feed: nil) }

            let object = CoreDataBackedArray(expectedArticles)
            expect(Array(object)).to(equal(expectedArticles))
        }

        it("should allow itself to be appended to") {
            let article = Article(title: "025", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [])

            subject.append(article)

            expect(subject.count).to(equal(36))

            let expectedArticles = articles.map { Article(article: $0, feed: nil) }
            expect(Array(subject)).to(equal(expectedArticles + [article]))

            let queryList = CoreDataBackedArray(expectedArticles)
            queryList.append(article)
            expect(Array(queryList)).to(equal(expectedArticles + [article]))
        }

        it("should work well with filter") {
            let results = subject.filter { $0.title == "001" }
            expect(results).to(equal([Article(article: articles[1], feed: nil)]))
        }

        it("should allow a filter with a predicate") {
            let results = subject.filterWithPredicate(NSPredicate(format: "title == %@", "001"))
            expect(Array(results)).to(equal([Article(article: articles[1], feed: nil)]))
        }

        it("should allow itself to be combined with another CoreDataBackedArray easily") {
            expect(Array(subject.combine(subject))).to(equal(Array(subject))) // simple case

            let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)

            let a = CoreDataBackedArray(entityName: "Article", predicate: NSPredicate(format: "title == %@", "002"), managedObjectContext: moc, conversionFunction: {
                return Article(article: $0 as! CoreDataArticle, feed: nil)
            }, sortDescriptors: [sortDescriptor])

            let b = CoreDataBackedArray(entityName: "Article", predicate: NSPredicate(format: "title == %@", "003"), managedObjectContext: moc, conversionFunction: {
                return Article(article: $0 as! CoreDataArticle, feed: nil)
            }, sortDescriptors: [sortDescriptor])

            let articles = articles.map({ Article(article: $0, feed: nil) })

            expect(Array(a.combine(b))).to(equal([articles[2], articles[3]]))
        }

        it("should allow itself to be combined with other predicates") {
            let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)

            let a = CoreDataBackedArray(entityName: "Article", predicate: NSPredicate(format: "title == %@", "003"), managedObjectContext: moc, conversionFunction: {
                return Article(article: $0 as! CoreDataArticle, feed: nil)
                }, sortDescriptors: [sortDescriptor])

            let predicate = NSPredicate(format: "title == %@", "002")

            let articles = articles.map({ Article(article: $0, feed: nil) })

            expect(Array(a.combineWithPredicate(predicate))).to(equal([articles[2], articles[3]]))
        }

        it("should allow an object to be removed from it") {
            let articles = articles.map({ Article(article: $0, feed: nil) })
            let toRemove = articles[4]

            expect(subject.remove(toRemove)).to(beTruthy())
            expect(subject.count).to(equal(34))

            let expectedArticles = articles.filter { $0.title != toRemove.title }
            expect(Array(subject)).to(equal(expectedArticles))

            let article = Article(title: "025", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [])
            subject.append(article)
            expect(subject.count).to(equal(35))
            expect(subject.remove(article)).to(beTruthy())
            expect(Array(subject)).to(equal(expectedArticles))

            let queryList = CoreDataBackedArray(articles)
            expect(queryList.remove(toRemove)).to(beTruthy())
            expect(Array(queryList)).to(equal(expectedArticles))
        }
    }
}
