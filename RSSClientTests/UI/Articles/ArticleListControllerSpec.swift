import Quick
import Nimble
import Ra
import rNews
import rNewsKit
import UIKit

class FakeUIViewControllerPreviewing: NSObject, UIViewControllerPreviewing {
    @available(iOS 9.0, *)
    var previewingGestureRecognizerForFailureRelationship: UIGestureRecognizer {
        return UIGestureRecognizer()
    }

    private let _delegate: NSObject?

    @available(iOS 9.0, *)
    var delegate: UIViewControllerPreviewingDelegate {
        if let delegate = _delegate as? UIViewControllerPreviewingDelegate {
            return delegate
        }
        fatalError("_delegate was not set")
    }

    private let _sourceView: UIView

    @available(iOS 9.0, *)
    var sourceView: UIView {
        return _sourceView
    }

    private var _sourceRect: CGRect

    @available(iOS 9.0, *)
    var sourceRect: CGRect {
        get { return _sourceRect }
        set { _sourceRect = newValue }
    }

    init(sourceView: UIView, sourceRect: CGRect, delegate: NSObject) {
        self._sourceView = sourceView
        self._sourceRect = sourceRect
        self._delegate = delegate
    }
}

private var publishedOffset = -1
func fakeArticle(feed: Feed, isUpdated: Bool = false, read: Bool = false) -> Article {
    publishedOffset += 1
    let publishDate: Date
    let updatedDate: Date?
    if isUpdated {
        updatedDate = Date(timeIntervalSinceReferenceDate: TimeInterval(publishedOffset))
        publishDate = Date(timeIntervalSinceReferenceDate: 0)
    } else {
        publishDate = Date(timeIntervalSinceReferenceDate: TimeInterval(publishedOffset))
        updatedDate = nil
    }
    return Article(title: "article \(publishedOffset)", link: URL(string: "http://example.com"), summary: "", authors: [Author(name: "Rachel", email: nil)], published: publishDate, updatedAt: updatedDate, identifier: "\(publishedOffset)", content: "", read: read, estimatedReadingTime: 0, feed: feed, flags: [])
}

class ArticleListControllerSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil
        var mainQueue: FakeOperationQueue! = nil
        var feed: Feed! = nil
        var subject: ArticleListController! = nil
        var navigationController: UINavigationController! = nil
        var articles: [Article] = []
        var dataRepository: FakeDatabaseUseCase! = nil
        var themeRepository: ThemeRepository! = nil
        var settingsRepository: SettingsRepository! = nil

        beforeEach {
            injector = Injector()

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            injector.bind(string: kMainQueue, toInstance: mainQueue)

            settingsRepository = SettingsRepository(userDefaults: nil)
            injector.bind(kind: SettingsRepository.self, toInstance: settingsRepository)

            let useCase = FakeArticleUseCase()
            useCase.readArticleReturns("hello")
            useCase.userActivityForArticleReturns(NSUserActivity(activityType: "com.example.test"))
            injector.bind(kind: ArticleUseCase.self, toInstance: useCase)

            themeRepository = ThemeRepository(userDefaults: nil)
            injector.bind(kind: ThemeRepository.self, toInstance: themeRepository)

            dataRepository = FakeDatabaseUseCase()
            injector.bind(kind: DatabaseUseCase.self, toInstance: dataRepository)

            publishedOffset = 0

            feed = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            let d = fakeArticle(feed: feed)
            let c = fakeArticle(feed: feed, read: true)
            let b = fakeArticle(feed: feed, isUpdated: true)
            let a = fakeArticle(feed: feed)
            articles = [a, b, c, d]

            for article in articles {
                feed.addArticle(article)
            }

            subject = injector.create(kind: ArticleListController.self)!
            subject.feed = feed

            navigationController = UINavigationController(rootViewController: subject)

            subject.view.layoutIfNeeded()
        }

        fit("dismisses the keyboard upon drag") {
            expect(subject.tableView.keyboardDismissMode).to(equal(UIScrollViewKeyboardDismissMode.onDrag))
        }

        describe("when a feed is backing the list") {
            beforeEach {
                subject.feed = feed
            }

            it("displays a share sheet icon for sharing that feed") {
                expect(subject.navigationItem.rightBarButtonItems?.count) == 2
                expect(subject.navigationItem.rightBarButtonItems?.first) == subject.editButtonItem
                if let shareSheet = subject.navigationItem.rightBarButtonItems?.last {
                    shareSheet.tap()
                    expect(subject.presentedViewController).to(beAnInstanceOf(UIActivityViewController.self))
                    if let activityVC = subject.presentedViewController as? UIActivityViewController {
                        expect(activityVC.activityItems as? [URL]) == [feed.url]
                    }
                }
            }
        }

        describe("when a feed is not backing the list") {
            beforeEach {
                subject.feed = nil
            }

            it("does not display a share sheet icon for sharing that feed") {
                expect(subject.navigationItem.rightBarButtonItems?.count) == 1
                expect(subject.navigationItem.rightBarButtonItems?.first) == subject.editButtonItem
            }
        }

        describe("listening to theme repository updates") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("should update the tableView") {
                expect(subject.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                expect(subject.tableView.separatorColor).to(equal(themeRepository.textColor))
            }

            it("should update the tableView scroll indicator style") {
                expect(subject.tableView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
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
                    let cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: IndexPath(row: 3, section: 0)) as! ArticleCell

                    expect(cell.unread.unread).to(equal(1))

                    articles[3].read = true
                    for subscriber in dataRepository.subscribersArray {
                        subscriber.markedArticles([articles[3]], asRead: true)
                    }
                }

                it("should reload the tableView") {
                    let cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: IndexPath(row: 3, section: 0)) as! ArticleCell

                    expect(cell.unread.unread).to(equal(0))
                }
            }
        }

        describe("force pressing a cell") {
            var viewControllerPreviewing: FakeUIViewControllerPreviewing! = nil

            beforeEach {
                viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)
            }

            context("in preview mode") {
                beforeEach {
                    subject.previewMode = true
                }

                it("should not return a view controller to present to the user") {
                    let rect = subject.tableView.rectForRow(at: IndexPath(row: 0, section: 0))
                    let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                    let viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                    expect(viewController).to(beNil())
                }
            }

            context("out of preview mode") {
                var viewController: UIViewController? = nil

                beforeEach {
                    subject.previewMode = false

                    let rect = subject.tableView.rectForRow(at: IndexPath(row: 0, section: 0))
                    let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                    viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                }

                it("should return an ArticleViewController configured with the article to present to the user") {
                    expect(viewController).to(beAKindOf(ArticleViewController.self))
                    if let articleVC = viewController as? ArticleViewController {
                        expect(articleVC.article).to(equal(articles[0]))                    }
                }

                it("should not mark the article as read") {
                    expect(articles[0].read) == false
                    expect(dataRepository.lastArticleMarkedRead).to(beNil())
                }

                describe("committing that view controller") {
                    beforeEach {
                        if let vc = viewController {
                            subject.previewingContext(viewControllerPreviewing, commit: vc)
                        }
                    }

                    it("should push the view controller") {
                        expect(navigationController.topViewController).to(beIdenticalTo(viewController))
                    }

                    it("should mark the article as read") {
                        expect(articles[0].read) == true
                        expect(dataRepository.lastArticleMarkedRead).to(equal(articles[0]))
                    }
                }
            }
        }

        describe("the table") {
            it("should have 1 secton") {
                expect(subject.tableView.numberOfSections).to(equal(1))
            }

            it("should have a row for each article") {
                expect(subject.tableView.numberOfRows(inSection: 0)).to(equal(articles.count))
            }

            describe("the cells") {
                context("in preview mode") {
                    beforeEach {
                        subject.previewMode = true
                    }

                    it("should not be editable") {
                        for section in 0..<subject.tableView.numberOfSections {
                            for row in 0..<subject.tableView.numberOfRows(inSection: section) {
                                let indexPath = IndexPath(row: row, section: section)
                                expect(subject.tableView(subject.tableView, canEditRowAt: indexPath)) == false
                            }
                        }
                    }

                    it("should have no edit actions") {
                        for section in 0..<subject.tableView.numberOfSections {
                            for row in 0..<subject.tableView.numberOfRows(inSection: section) {
                                let indexPath = IndexPath(row: row, section: section)
                                expect(subject.tableView(subject.tableView, editActionsForRowAt: indexPath)).to(beNil())
                            }
                        }
                    }

                    describe("when tapped") {
                        beforeEach {
                            subject.tableView(subject.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
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
                            dataRepository.articlesOfFeedList = [articles.last!]
                            subject.searchBar.delegate?.searchBar?(subject.searchBar, textDidChange: "\(publishedOffset)")
                        }

                        it("should resign first responder when the tableView is scrolled") {
                            subject.tableView.delegate?.scrollViewDidScroll?(subject.tableView)

                            expect(subject.searchBar.isFirstResponder) == false
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

                    it("has a set settings repository") {
                        for section in 0..<subject.tableView.numberOfSections {
                            for row in 0..<subject.tableView.numberOfRows(inSection: section) {
                                let indexPath = IndexPath(row: row, section: section)
                                let cell = subject.tableView(subject.tableView, cellForRowAt: indexPath) as? ArticleCell
                                expect(cell).toNot(beNil())
                                expect(cell?.settingsRepository) === settingsRepository
                            }
                        }
                    }

                    it("should be editable") {
                        for section in 0..<subject.tableView.numberOfSections {
                            for row in 0..<subject.tableView.numberOfRows(inSection: section) {
                                let indexPath = IndexPath(row: row, section: section)
                                expect(subject.tableView(subject.tableView, canEditRowAt: indexPath)) == true
                            }
                        }
                    }

                    it("should have 2 edit actions") {
                        for section in 0..<subject.tableView.numberOfSections {
                            for row in 0..<subject.tableView.numberOfRows(inSection: section) {
                                let indexPath = IndexPath(row: row, section: section)
                                expect(subject.tableView(subject.tableView, editActionsForRowAt: indexPath)?.count).to(equal(2))
                            }
                        }
                    }

                    describe("the edit actions") {
                        describe("the first action") {
                            var action: UITableViewRowAction! = nil
                            let indexPath = IndexPath(row: 0, section: 0)

                            beforeEach {
                                action = subject.tableView(subject.tableView, editActionsForRowAt: indexPath)?.first
                            }

                            it("states that it deletes the article") {
                                expect(action?.title) == "Delete"
                            }

                            describe("tapping it") {
                                beforeEach {
                                    action.handler(action, indexPath)
                                }

                                it("does not yet delete the article") {
                                    expect(dataRepository.lastDeletedArticle).to(beNil())
                                }

                                it("presents an alert asking for confirmation that the user wants to do this") {
                                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                    guard let alert = subject.presentedViewController as? UIAlertController else { return }
                                    expect(alert.preferredStyle) == UIAlertControllerStyle.alert
                                    expect(alert.title) == "Delete \(articles.first!.title)?"

                                    expect(alert.actions.count) == 2
                                    expect(alert.actions.first?.title) == "Delete"
                                    expect(alert.actions.last?.title) == "Cancel"
                                }

                                describe("tapping 'Delete'") {
                                    beforeEach {
                                        expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                        guard let alert = subject.presentedViewController as? UIAlertController else { return }

                                        alert.actions.first?.handler(alert.actions.first!)
                                    }

                                    it("deletes the article") {
                                        expect(dataRepository.lastDeletedArticle) == articles.first
                                    }

                                    it("dismisses the alert") {
                                        expect(subject.presentedViewController).to(beNil())
                                    }
                                }

                                describe("tapping 'Cancel'") {
                                    beforeEach {
                                        expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                        guard let alert = subject.presentedViewController as? UIAlertController else { return }

                                        alert.actions.last?.handler(alert.actions.last!)
                                    }

                                    it("does not delete the article") {
                                        expect(dataRepository.lastDeletedArticle).to(beNil())
                                    }

                                    it("dismisses the alert") {
                                        expect(subject.presentedViewController).to(beNil())
                                    }
                                }
                            }
                        }

                        describe("for an unread article") {
                            it("should mark the article as read with the second action item") {
                                let indexPath = IndexPath(row: 0, section: 0)
                                if let markRead = subject.tableView(subject.tableView, editActionsForRowAt: indexPath)?.last {
                                    expect(markRead.title).to(equal("Mark\nRead"))
                                    markRead.handler(markRead, indexPath)
                                    expect(dataRepository.lastArticleMarkedRead).to(equal(articles.first))
                                    expect(articles.first?.read) == true
                                }
                            }
                        }

                        describe("for a read article") {
                            it("should mark the article as unread with the second action item") {
                                let indexPath = IndexPath(row: 2, section: 0)
                                if let markUnread = subject.tableView(subject.tableView, editActionsForRowAt: indexPath)?.last {
                                    expect(markUnread.title).to(equal("Mark\nUnread"))
                                    markUnread.handler(markUnread, indexPath)
                                    expect(dataRepository.lastArticleMarkedRead).to(equal(articles[2]))
                                    expect(articles[2].read) == false
                                }
                            }
                        }
                    }

                    describe("when tapped") {
                        beforeEach {
                            subject.tableView(subject.tableView, didSelectRowAt: IndexPath(row: 1, section: 0))
                        }

                        it("should navigate to an ArticleViewController") {
                            expect(navigationController.topViewController).to(beAnInstanceOf(ArticleViewController.self))
                            if let articleController = navigationController.topViewController as? ArticleViewController {
                                expect(articleController.article).to(equal(articles[1]))
                            }
                        }
                    }
                }
            }
        }
    }
}
