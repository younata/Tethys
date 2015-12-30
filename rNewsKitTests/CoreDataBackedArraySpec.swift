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
            let expectedArticles = Array(articles[0..<25]).map { Article(article: $0, feed: nil) }
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
    }
}
