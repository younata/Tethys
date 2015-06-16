import Quick
import Nimble
import Ra
import rNews

private var publishedOffset = -1
func fakeArticle(feed: Feed, isUpdated: Bool = false, read: Bool = false) -> Article {
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
    return Article(title: "article \(publishedOffset)", link: nil, summary: "", author: "Rachel", published: publishDate, updatedAt: updatedDate, identifier: "\(publishedOffset)", content: "", read: read, feed: feed, flags: [], enclosures: [])
}

class ArticleListControllerSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil
        var mainQueue: FakeOperationQueue! = nil
        var feed: Feed! = nil
        var subject: ArticleListController! = nil
        var navigationController: UINavigationController! = nil
        var articles: [Article] = []
        var sortedArticles: [Article] = []
        var dataManager: DataManagerMock! = nil

        beforeEach {
            injector = Injector()

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            injector.bind(kMainQueue, to: mainQueue)

            dataManager = DataManagerMock()
            injector.bind(DataManager.self, to: dataManager)

            publishedOffset = 0

            feed = Feed(title: "", url: NSURL(string: "https://example.com"), summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
            let a = fakeArticle(feed)
            let b = fakeArticle(feed, read: true)
            let c = fakeArticle(feed, isUpdated: true)
            let d = fakeArticle(feed)
            articles = [d, c, b, a]
            sortedArticles = [a, b, c, d]

            subject = injector.create(ArticleListController.self) as! ArticleListController
            subject.feeds = [feed]

            navigationController = UINavigationController(rootViewController: subject)

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

                    it("should not be editable") {
                        for section in 0..<subject.tableView.numberOfSections {
                            for row in 0..<subject.tableView.numberOfRowsInSection(section) {
                                let indexPath = NSIndexPath(forRow: row, inSection: section)
                                expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)).to(beFalsy())
                            }
                        }
                    }

                    it("should have no edit actions") {
                        for section in 0..<subject.tableView.numberOfSections {
                            for row in 0..<subject.tableView.numberOfRowsInSection(section) {
                                let indexPath = NSIndexPath(forRow: row, inSection: section)
                                expect(subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath)).to(beNil())
                            }
                        }
                    }

                    describe("when tapped") {
                        beforeEach {
                            subject.tableView(subject.tableView, didSelectRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 0))
                        }

                        it("nothing should happen") {
                            expect(navigationController.topViewController).to(beIdenticalTo(subject))
                        }
                    }
                }

                context("out of preview mode") {
                    it("should be editable") {
                        for section in 0..<subject.tableView.numberOfSections {
                            for row in 0..<subject.tableView.numberOfRowsInSection(section) {
                                let indexPath = NSIndexPath(forRow: row, inSection: section)
                                expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)).to(beTruthy())
                            }
                        }
                    }

                    it("should have 2 edit actions") {
                        for section in 0..<subject.tableView.numberOfSections {
                            for row in 0..<subject.tableView.numberOfRowsInSection(section) {
                                let indexPath = NSIndexPath(forRow: row, inSection: section)
                                expect(subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath)?.count).to(equal(2))
                            }
                        }
                    }

                    describe("the edit actions") {

                        it("should delete the article with the first action item") {
                            let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                            if let delete = subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath)?.first {
                                expect(delete.title).to(equal("Delete"))
                                delete.handler()(delete, indexPath)
                                expect(dataManager.lastDeletedArticle).to(equal(sortedArticles.first))
                            }
                        }

                        describe("for an unread article") {
                            it("should mark the article as read with the second action item") {
                                let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                                if let markRead = subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath)?.last {
                                    expect(markRead.title).to(equal("Mark\nRead"))
                                    // no idea.
//                                    markRead.handler()(markRead, indexPath)
//                                    expect(dataManager.lastDeletedArticle).to(equal(sortedArticles.first))
                                }
                            }
                        }

                        describe("for a read article") {
                            it("should mark the article as unread with the second action item") {
                                let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                                if let markRead = subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath)?.last {
                                    expect(markRead.title).to(equal("Mark\nRead"))
                                }
                            }
                        }
                    }

                    describe("when tapped") {
                        beforeEach {
                            subject.tableView(subject.tableView, didSelectRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 0))
                        }

                        it("should navigate to an ArticleViewController") {
                            expect(navigationController.topViewController).to(beAnInstanceOf(ArticleViewController.self))
//                            if let articleController = navigationController.topViewController as? ArticleViewController {
//                                expect(articleController.art).to(<#Matcher#>)
//                            }
                        }
                    }
                }
            }
        }
    }
}
