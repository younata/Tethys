import Quick
import Nimble
import Ra
import rNews

private var publishedOffset = -1
func fakeArticle(feed: Feed, isUpdated: Bool = false) -> Article {
    publishedOffset++
    let publishDate: NSDate
    let updatedDate: NSDate?
    if isUpdated {
        updatedDate = NSDate(timeIntervalSinceReferenceDate: NSTimeInterval(publishedOffset))
        publishDate = NSDate(timeIntervalSinceReferenceDate: 0)
    } else {
        publishDate = NSDate(timeIntervalSinceReferenceDate: NSTimeInterval(publishedOffset))
        updatedDate = nil
    }
    return Article(title: "article \(publishedOffset)", link: nil, summary: "", author: "Rachel", published: publishDate, updatedAt: updatedDate, identifier: "\(publishedOffset)", content: "", read: false, feed: feed, flags: [], enclosures: [])
}

class ArticleListControllerSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil
        var mainQueue: FakeOperationQueue! = nil
        var feed: Feed! = nil
        var subject: ArticleListController! = nil
        var articles: [Article] = []
        var sortedArticles: [Article] = []

        beforeEach {
            injector = Injector()

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            injector.bind(kMainQueue, to: mainQueue)

            publishedOffset = 0

            feed = Feed(title: "", url: NSURL(string: "https://example.com"), summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
            let a = fakeArticle(feed)
            let b = fakeArticle(feed)
            let c = fakeArticle(feed, isUpdated: true)
            let d = fakeArticle(feed)
            articles = [d, c, b, a]
            sortedArticles = [a, b, c, d]

            subject = injector.create(ArticleListController.self) as! ArticleListController
            subject.feeds = [feed]

            subject.view.layoutIfNeeded()
        }

        // displays a list of articles.
        // when in preview mode, there is no user-interaction

        describe("the table") {
            it("should have 1 secton") {
                expect(subject.tableView.numberOfSections).to(equal(1))
            }

            it("should have a row for each article") {
                expect(subject.tableView.numberOfRowsInSection(0)).to(equal(articles.count))
            }

            describe("the cells") {
                it("should be sorted") {
                    for (idx, article) in sortedArticles.enumerate() {
                        let indexPath = NSIndexPath(forRow: idx, inSection: 0)
                        let cell = subject.tableView(subject.tableView, cellForRowAtIndexPath: indexPath) as! ArticleCell
                        expect(cell.article).to(equal(article))
                    }
                }

                context("in preview mode") {
                    beforeEach {
                        subject.previewMode = true
                    }
                }

                context("out of preview mode") {

                }
            }
        }
    }
}
