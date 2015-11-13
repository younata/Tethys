import Quick
import Nimble
import Ra
import rNews
import rNewsKit

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
    return Article(title: "article \(publishedOffset)", link: NSURL(string: "http://example.com"), summary: "", author: "Rachel", published: publishDate, updatedAt: updatedDate, identifier: "\(publishedOffset)", content: "", read: read, feed: feed, flags: [], enclosures: [])
}

class ArticleListControllerSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil
        var mainQueue: FakeOperationQueue! = nil
        var feed: Feed! = nil
        var subject: ArticleListController! = nil
        var navigationController: UINavigationController! = nil
        var articles: [Article] = []
        var dataReadWriter: FakeDataReadWriter! = nil
        var themeRepository: FakeThemeRepository! = nil

        beforeEach {
            injector = Injector()

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            injector.bind(kMainQueue, to: mainQueue)

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, to: themeRepository)

            dataReadWriter = FakeDataReadWriter()
            injector.bind(DataRetriever.self, to: dataReadWriter)
            injector.bind(DataWriter.self, to: dataReadWriter)

            publishedOffset = 0

            feed = Feed(title: "", url: NSURL(string: "https://example.com"), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            let d = fakeArticle(feed)
            let c = fakeArticle(feed, read: true)
            let b = fakeArticle(feed, isUpdated: true)
            let a = fakeArticle(feed)
            articles = [a, b, c, d]

            for article in articles {
                feed.addArticle(article)
            }

            subject = injector.create(ArticleListController.self) as! ArticleListController
            subject.feeds = [feed]

            navigationController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("listening to theme repository updates") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should update the tableView") {
                expect(subject.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                expect(subject.tableView.separatorColor).to(equal(themeRepository.textColor))
            }

            it("should update the navigation bar background") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
            }

            it("should update the searchbar") {
                expect(subject.searchBar.barStyle).to(equal(themeRepository.barStyle))
                expect(subject.searchBar.backgroundColor).to(equal(themeRepository.backgroundColor))
            }
        }

        describe("as a DataSubscriber") {
            describe("markedArticle:asRead:") {
                beforeEach {
                    let cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAtIndexPath: NSIndexPath(forRow: 3, inSection: 0)) as! ArticleCell

                    expect(cell.unread.unread).to(equal(1))

                    articles[3].read = true
                    for object in dataReadWriter.subscribers.allObjects {
                        if let subscriber = object as? DataSubscriber {
                            subscriber.markedArticles([articles[3]], asRead: true)
                        }
                    }
                }

                it("should reload the tableView") {
                    let cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAtIndexPath: NSIndexPath(forRow: 3, inSection: 0)) as! ArticleCell

                    expect(cell.unread.unread).to(equal(0))
                }
            }
        }

        describe("the table") {
            it("should have 1 secton") {
                expect(subject.tableView.numberOfSections).to(equal(1))
            }

            it("should have a row for each article") {
                expect(subject.tableView.numberOfRowsInSection(0)).to(equal(articles.count))
            }

            describe("the cells") {
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
                    describe("typing in the search bar") {
                        beforeEach {
                            subject.searchBar.becomeFirstResponder()
                            subject.searchBar.text = "\(publishedOffset)"
                            dataReadWriter.articlesOfFeedList = [articles.last!]
                            subject.searchBar.delegate?.searchBar?(subject.searchBar, textDidChange: "\(publishedOffset)")
                        }

                        it("should resign first responder when the tableView is scrolled") {
                            subject.tableView.delegate?.scrollViewDidScroll?(subject.tableView)

                            expect(subject.searchBar.isFirstResponder()).to(beFalsy())
                        }

                        it("should filter the articles down to those that match the query") {
                            expect(subject.tableView(subject.tableView, numberOfRowsInSection: 0)).to(equal(1))
                        }

                        describe("clearing the searchbar") {
                            beforeEach {
                                subject.searchBar.text = ""
                                subject.searchBar.delegate?.searchBar?(subject.searchBar, textDidChange: "")
                            }

                            it("should reset the articles") {
                                expect(subject.tableView(subject.tableView, numberOfRowsInSection: 0)).to(equal(articles.count))
                            }
                        }
                    }

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
                                expect(dataReadWriter.lastDeletedArticle).to(equal(articles.first))
                            }
                        }

                        describe("for an unread article") {
                            it("should mark the article as read with the second action item") {
                                let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                                if let markRead = subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath)?.last {
                                    expect(markRead.title).to(equal("Mark\nRead"))
                                    markRead.handler()(markRead, indexPath)
                                    expect(dataReadWriter.lastArticleMarkedRead).to(equal(articles.first))
                                    expect(articles.first?.read).to(beTruthy())
                                }
                            }
                        }

                        describe("for a read article") {
                            it("should mark the article as unread with the second action item") {
                                let indexPath = NSIndexPath(forRow: 2, inSection: 0)
                                if let markUnread = subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath)?.last {
                                    expect(markUnread.title).to(equal("Mark\nUnread"))
                                    markUnread.handler()(markUnread, indexPath)
                                    expect(dataReadWriter.lastArticleMarkedRead).to(equal(articles[2]))
                                    expect(articles[2].read).to(beFalsy())
                                }
                            }
                        }
                    }

                    describe("when tapped") {
                        beforeEach {
                            subject.tableView(subject.tableView, didSelectRowAtIndexPath: NSIndexPath(forRow: 1, inSection: 0))
                        }

                        it("should navigate to an ArticleViewController") {
                            expect(navigationController.topViewController).to(beAnInstanceOf(ArticleViewController.self))
                            if let articleController = navigationController.topViewController as? ArticleViewController {
                                expect(articleController.article).to(equal(articles[1]))
                                expect(Array(articleController.articles)).to(equal(articles))
                                expect(articleController.lastArticleIndex).to(equal(1))
                            }
                        }
                    }
                }
            }
        }
    }
}
