import Quick
import Nimble
@testable import Tethys
import TethysKit
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

class FakeArticleListControllerDelegate: ArticleListControllerDelegate {
    var canSelectMultipleArticlesCallCount = 0
    var canSelectMultipleArticlesReturns: ((ArticleListController) -> Bool)?
    func articleListControllerCanSelectMultipleArticlesReturns(_ returnValue: Bool) {
        self.canSelectMultipleArticlesReturns = { _ in return returnValue }
    }
    func articleListControllerCanSelectMultipleArticles(_ articleListController: ArticleListController) -> Bool {
        canSelectMultipleArticlesCallCount += 1
        return self.canSelectMultipleArticlesReturns!(articleListController)
    }

    var shouldShowToolBarCallCount = 0
    var shouldShowToolBarReturns: ((ArticleListController) -> Bool)?
    func articleListControllerShouldShowToolbarReturns(_ returnValue: Bool) {
        self.shouldShowToolBarReturns = { _ in return returnValue }
    }
    func articleListControllerShouldShowToolbar(_ articleListController: ArticleListController) -> Bool {
        self.shouldShowToolBarCallCount += 1
        return self.shouldShowToolBarReturns!(articleListController)
    }

    var rightBarButtonItemsCallCount = 0
    var rightBarButtonItemsReturns: ((ArticleListController) -> [UIBarButtonItem])?
    func articleListControllerRightBarButtonItemsReturns(_ returnValue: [UIBarButtonItem]) {
        self.rightBarButtonItemsReturns = { _ in return returnValue }
    }
    func articleListControllerRightBarButtonItems(_ articleListController: ArticleListController) -> [UIBarButtonItem] {
        self.rightBarButtonItemsCallCount += 1
        return self.rightBarButtonItemsReturns?(articleListController) ?? []
    }

    var canEditArticleCallCount = 0
    var canEditArticleReturns: ((ArticleListController, Article) -> Bool)?
    func articleListControllecCanEditArticleReturns(_ returnValue: Bool) {
        self.canEditArticleReturns = { _ in return returnValue }
    }
    var canEditArticleArgs: [(ArticleListController, Article)] = []
    func canEditArticleArgsForCall(_ callIndex: Int) -> (ArticleListController, Article) {
        return canEditArticleArgs[callIndex]
    }
    func articleListController(_ articleListController: ArticleListController, canEditArticle article: Article) -> Bool {
        self.canEditArticleCallCount += 1
        self.canEditArticleArgs.append((articleListController, article))
        return self.canEditArticleReturns!(articleListController, article)
    }

    var shouldShowArticleViewCallCount = 0
    var shouldShowArticleViewReturns: ((ArticleListController, Article) -> Bool)?
    func articleListControllerShouldShowArticleViewReturns(_ returnValue: Bool) {
        self.shouldShowArticleViewReturns = { _ in return returnValue }
    }
    var shouldShowArticleViewArgs: [(ArticleListController, Article)] = []
    func shouldShowArticleViewArgsForCall(_ callIndex: Int) -> (ArticleListController, Article) {
        return self.shouldShowArticleViewArgs[callIndex]
    }
    func articleListController(_ articleListController: ArticleListController, shouldShowArticleView article: Article) -> Bool {
        self.shouldShowArticleViewCallCount += 1
        self.shouldShowArticleViewArgs.append((articleListController, article))
        return self.shouldShowArticleViewReturns!(articleListController, article)
    }

    var didSelectArticlesCallCount = 0
    var didSelectArticlesArgs: [(ArticleListController, [Article])] = []
    func didSelectArticlesArgsForCall(_ callIndex: Int) -> (ArticleListController, [Article]) {
        return self.didSelectArticlesArgs[callIndex]
    }
    func articleListController(_ articleListController: ArticleListController, didSelectArticles articles: [Article]) {
        self.didSelectArticlesCallCount += 1
        self.didSelectArticlesArgs.append((articleListController, articles))
    }

    var shouldPreviewArticleCallCount = 0
    var shouldPreviewArticleReturns: ((ArticleListController, Article) -> Bool)?
    func articleListControllerShouldPreviewArticleReturns(_ returnValue: Bool) {
        self.shouldPreviewArticleReturns = { _ in return returnValue }
    }
    var shouldPreviewArticleArgs: [(ArticleListController, Article)] = []
    func shouldPreviewArticleArgsForCall(_ callIndex: Int) -> (ArticleListController, Article) {
        return self.shouldPreviewArticleArgs[callIndex]
    }
    func articleListController(_ articleListController: ArticleListController, shouldPreviewArticle article: Article) -> Bool {
        self.shouldPreviewArticleCallCount += 1
        self.shouldPreviewArticleArgs.append((articleListController, article))
        return self.shouldPreviewArticleReturns!((articleListController, article))
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
    return Article(title: "article \(publishedOffset)", link: URL(string: "http://example.com")!, summary: "", authors: [Author(name: "Rachel", email: nil)], published: publishDate, updatedAt: updatedDate, identifier: "\(publishedOffset)", content: "", read: read, synced: false, feed: feed, flags: [])
}

class ArticleListControllerSpec: QuickSpec {
    override func spec() {
        var mainQueue: FakeOperationQueue!
        var feed: Feed!
        var subject: ArticleListController!
        var navigationController: UINavigationController!
        var articles: [Article] = []
        var dataRepository: FakeDatabaseUseCase!
        var articleService: FakeArticleService!
        var themeRepository: ThemeRepository!
        var settingsRepository: SettingsRepository!
        var articleCellController: FakeArticleCellController!

        beforeEach {
            mainQueue = FakeOperationQueue()
            settingsRepository = SettingsRepository(userDefaults: nil)

            let useCase = FakeArticleUseCase()
            useCase.readArticleReturns("hello")

            themeRepository = ThemeRepository(userDefaults: nil)
            dataRepository = FakeDatabaseUseCase()

            publishedOffset = 0

            feed = Feed(title: "", url: URL(string: "https://example.com")!, summary: "hello world", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            let d = fakeArticle(feed: feed)
            let c = fakeArticle(feed: feed, read: true)
            let b = fakeArticle(feed: feed, isUpdated: true)
            let a = fakeArticle(feed: feed)
            articles = [a, b, c, d]

            for article in articles {
                feed.addArticle(article)
            }

            articleService = FakeArticleService()
            articleCellController = FakeArticleCellController()

            subject = ArticleListController(
                mainQueue: mainQueue,
                articleService: articleService,
                feedRepository: dataRepository,
                themeRepository: themeRepository,
                settingsRepository: settingsRepository,
                articleCellController: articleCellController,
                articleViewController: { articleViewControllerFactory(articleUseCase: useCase) },
                generateBookViewController: {
                    return generateBookViewControllerFactory()
                }
            )

            navigationController = UINavigationController(rootViewController: subject)
        }

        it("dismisses the keyboard upon drag") {
            subject.view.layoutIfNeeded()
            expect(subject.tableView.keyboardDismissMode).to(equal(UIScrollViewKeyboardDismissMode.onDrag))
        }

        describe("selectArticles") {
            var delegate: FakeArticleListControllerDelegate!
            beforeEach {
                delegate = FakeArticleListControllerDelegate()
                delegate.articleListControllerShouldShowArticleViewReturns(false)
                delegate.articleListControllerCanSelectMultipleArticlesReturns(true)
                delegate.articleListControllecCanEditArticleReturns(false)
                delegate.articleListControllerShouldShowToolbarReturns(false)
                subject.delegate = delegate

                subject.view.layoutIfNeeded()
                subject.feed = feed
                subject.viewWillAppear(true)

                let indexPath = IndexPath(row: 0, section: 1)
                let secondIndexPath = IndexPath(row: 1, section: 1)
                subject.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                subject.tableView.selectRow(at: secondIndexPath, animated: false, scrollPosition: .none)

                subject.selectArticles()
            }

            it("calls the delegate with didSelectArticles") {
                expect(delegate.didSelectArticlesCallCount) == 1

                let articles = [
                    feed.articlesArray[0],
                    feed.articlesArray[1]
                ]

                let args = delegate.didSelectArticlesArgsForCall(0)

                expect(args.0) == subject
                expect(args.1) == articles
            }
        }

        describe("the bar button items") {
            describe("with a delegate") {
                let barButtonItem = UIBarButtonItem(title: "hello", style: .plain, target: nil, action: nil)
                it("uses the bar buttons specified by the delegate") {
                    let delegate = FakeArticleListControllerDelegate()
                    delegate.articleListControllerCanSelectMultipleArticlesReturns(true)
                    delegate.articleListControllecCanEditArticleReturns(false)
                    delegate.articleListControllerRightBarButtonItemsReturns([
                        barButtonItem
                    ])
                    subject.delegate = delegate
                    subject.view.layoutIfNeeded()

                    expect(subject.navigationItem.rightBarButtonItems) == [barButtonItem]
                }
            }

            describe("without one") { // current behavior
                describe("when a feed is backing the list") {
                    beforeEach {
                        subject.view.layoutIfNeeded()

                        subject.feed = feed
                    }

                    it("displays a share sheet icon for sharing that feed") {
                        expect(subject.navigationItem.rightBarButtonItems?.count) == 2
                        expect(subject.navigationItem.rightBarButtonItems?.first) == subject.editButtonItem
                        if let shareSheet = subject.navigationItem.rightBarButtonItems?.last {
                            shareSheet.tap()
                            expect(subject.presentedViewController).to(beAnInstanceOf(URLShareSheet.self))
                            if let shareSheet = subject.presentedViewController as? URLShareSheet {
                                expect(shareSheet.url) == feed.url
                                expect(shareSheet.themeRepository) == themeRepository
                                expect(shareSheet.activityItems as? [URL]) == [feed.url]
                            }
                        }
                    }
                }

                describe("when a feed is not backing the list") {
                    beforeEach {
                        subject.view.layoutIfNeeded()

                        subject.feed = nil
                    }

                    it("does not display a share sheet icon for sharing that feed") {
                        expect(subject.navigationItem.rightBarButtonItems?.count) == 1
                        expect(subject.navigationItem.rightBarButtonItems?.first) == subject.editButtonItem
                    }
                }
            }
        }

        describe("the toolbar") {
            var delegate: FakeArticleListControllerDelegate!
            beforeEach {
                subject.view.layoutIfNeeded()
            }

            describe("when the delegate says not to show the toolbar") {
                beforeEach {
                    delegate = FakeArticleListControllerDelegate()
                    delegate.articleListControllerShouldShowToolbarReturns(false)
                    subject.delegate = delegate
                    subject.viewWillAppear(false)
                }

                it("does not show the toolbar") {
                    expect(navigationController.isToolbarHidden) == true
                }
            }

            describe("when the delegate says to show the toolbar") {
                beforeEach {
                    delegate = FakeArticleListControllerDelegate()
                    subject.delegate = delegate
                    delegate.articleListControllerShouldShowToolbarReturns(true)
                    subject.viewWillAppear(false)
                }

                it("shows the toolbar") {
                    expect(navigationController.isToolbarHidden) == false
                }
            }

            describe("when there is no delegate") {
                beforeEach {
                    subject.viewWillAppear(false)
                }

                it("shows the toolbar") {
                    expect(navigationController.isToolbarHidden) == false
                }
            }
        }

        describe("the toolbar items") {
            describe("when a feed is backing the list") {
                beforeEach {
                    subject.view.layoutIfNeeded()

                    subject.feed = feed
                }

                it("has 5 items") {
                    expect(subject.toolbarItems?.count) == 5
                }

                describe("the second toolBarItem") {
                    var item: UIBarButtonItem?

                    beforeEach {
                        item = subject.toolbarItems?[1]
                    }

                    it("Uses a book image") {
                        expect(item?.image) == UIImage(named: "Book")
                    }

                    it("presents a generate book controller when tapped") {
                        item?.tap()

                        expect(subject.presentedViewController).to(beAKindOf(UINavigationController.self))
                        if let navController = subject.navigationController?.visibleViewController as? UINavigationController {
                            expect(navController.visibleViewController).to(beAKindOf(GenerateBookViewController.self))
                            if let dataStoreArticles = (navController.visibleViewController as? GenerateBookViewController)?.articles {
                                expect(Array(dataStoreArticles)) == Array(subject.articles)
                            } else {
                                fail("setting generatebookcontroller articles")
                            }
                        } else {
                            fail("showing generatebookcontroller")
                        }
                    }
                }

                describe("the fourth toolBarItem") {
                    var item: UIBarButtonItem?

                    beforeEach {
                        item = subject.toolbarItems?[3]
                    }

                    it("is titled 'Mark Read'") {
                        expect(item?.title) == "Mark Read"
                    }

                    describe("tapping it") {
                        beforeEach {
                            item?.tap()
                        }

                        it("shows an indicator that we're doing things") {
                            let indicator = subject.view.subviews.filter {
                                return $0.isKind(of: ActivityIndicator.classForCoder())
                                }.first as? ActivityIndicator
                            expect(indicator?.message) == "Marking Articles as Read"
                        }

                        it("marks all articles of that feed as read") {
                            expect(dataRepository.lastFeedMarkedRead) == feed
                        }

                        describe("when the mark read promise succeeds") {
                            beforeEach {
                                dataRepository.lastFeedMarkedReadPromise?.resolve(.success(1))

                                mainQueue.runNextOperation()

                            }
                            it("removes the indicator") {
                                let indicator = subject.view.subviews.filter {
                                    return $0.isKind(of: ActivityIndicator.classForCoder())
                                    }.first
                                expect(indicator).to(beNil())
                            }
                        }

                        describe("when the mark read promise fails") {
                            beforeEach {
                                dataRepository.lastFeedMarkedReadPromise?.resolve(.failure(.database(.unknown)))
                                mainQueue.runNextOperation()
                            }

                            it("removes the indicator") {
                                let indicator = subject.view.subviews.filter {
                                    return $0.isKind(of: ActivityIndicator.classForCoder())
                                    }.first
                                expect(indicator).to(beNil())
                            }

                            it("shows an alert box") {
                                expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                if let alert = subject.presentedViewController as? UIAlertController {
                                    expect(alert.title) == "Unable to Mark Articles as Read"
                                    expect(alert.message) == "Unknown Database Error"
                                    expect(alert.actions.count) == 1
                                    if let action = alert.actions.first {
                                        expect(action.title) == "Ok"
                                        action.handler?(action)
                                        expect(subject.presentedViewController).to(beNil())
                                    }
                                }
                            }
                        }
                    }
                }
            }

            describe("when a feed is not backing the list") {
                beforeEach {
                    subject.view.layoutIfNeeded()
                    subject.feed = nil
                }

                it("it has a 3 items") {
                    expect(subject.toolbarItems?.count) == 3
                }

                describe("the second toolBarItem") {
                    var item: UIBarButtonItem?

                    beforeEach {
                        item = subject.toolbarItems?[1]
                    }

                    it("Uses a book image") {
                        expect(item?.image) == UIImage(named: "Book")
                    }

                    it("presents a generate book controller when tapped") {
                        item?.tap()

                        expect(subject.presentedViewController).to(beAKindOf(UINavigationController.self))
                        if let navController = subject.navigationController?.visibleViewController as? UINavigationController {
                            expect(navController.visibleViewController).to(beAKindOf(GenerateBookViewController.self))
                            if let dataStoreArticles = (navController.visibleViewController as? GenerateBookViewController)?.articles {
                                expect(Array(dataStoreArticles)) == Array(subject.articles)
                            } else {
                                fail("setting generatebookcontroller articles")
                            }
                        } else {
                            fail("showing generatebookcontroller")
                        }
                    }
                }
            }
        }

        describe("listening to theme repository updates") {
            beforeEach {
                subject.view.layoutIfNeeded()
                subject.viewWillAppear(false)
                themeRepository.theme = .dark
            }

            it("should update the tableView") {
                expect(subject.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                expect(subject.tableView.separatorColor).to(equal(themeRepository.textColor))
            }

            it("should update the tableView scroll indicator style") {
                expect(subject.tableView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
            }

            it("should update the navigation bar") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
                expect(subject.navigationController?.navigationBar.titleTextAttributes as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
            }

            it("updates the navigation toolbar") {
                expect(subject.navigationController?.toolbar.barStyle) == themeRepository.barStyle
            }
        }

        describe("as a DataSubscriber") {
            beforeEach {
                subject.feed = feed
                subject.view.layoutIfNeeded()
            }

            describe("markedArticle(_:asRead:)") {
                beforeEach {
                    articles[3].read = false
                    for subscriber in dataRepository.subscribersArray {
                        subscriber.markedArticles([articles[3]], asRead: true)
                    }
                }

                it("reloads the tableView") {
                    let cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: IndexPath(row: 3, section: 1)) as! ArticleCell

                    expect(articleCellController.configureCalls).to(haveCount(6)) // 3 articles, called twice for each.

                    guard let call = articleCellController.configureCalls.filter({ $0.article == articles[3] }).last else {
                        fail("No call for article3 found")
                        return
                    }

                    expect(call.cell).to(equal(cell))
                }
            }
        }

        describe("force pressing an article cell") {
            var viewControllerPreviewing: FakeUIViewControllerPreviewing! = nil
            let indexPath = IndexPath(row: 0, section: 1)

            beforeEach {
                viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)
            }

            context("when the delegate says to not preview articles") {
                var delegate: FakeArticleListControllerDelegate!
                beforeEach {
                    delegate = FakeArticleListControllerDelegate()
                    subject.delegate = delegate
                    delegate.articleListControllerShouldPreviewArticleReturns(false)
                    delegate.articleListControllecCanEditArticleReturns(false)
                    delegate.articleListControllerCanSelectMultipleArticlesReturns(false)
                    subject.view.layoutIfNeeded()
                    subject.feed = feed
                }

                it("does not return a view controller to present to the user") {
                    let rect = subject.tableView.rectForRow(at: indexPath)
                    let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                    let viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                    expect(viewController).to(beNil())
                }
            }

            context("when the delegate is not set") {
                var viewController: UIViewController? = nil

                beforeEach {
                    subject.view.layoutIfNeeded()
                    subject.feed = feed
                    let rect = subject.tableView.rectForRow(at: indexPath)
                    let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                    viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                }

                it("returns an ArticleViewController configured with the article to present to the user") {
                    expect(viewController).to(beAKindOf(ArticleViewController.self))
                    if let articleVC = viewController as? ArticleViewController {
                        expect(articleVC.article).to(equal(articles[0]))
                    }
                }

                it("does not mark the article as read") {
                    expect(articleService.markArticleAsReadCalls).to(haveCount(0))
                    expect(articles[0].read) == false
                }

                describe("the preview actions") {
                    var previewActions: [UIPreviewActionItem]?
                    var action: UIPreviewAction?

                    beforeEach {
                        previewActions = viewController?.previewActionItems
                        expect(previewActions).toNot(beNil())
                    }

                    it("has 2 preview actions") {
                        expect(previewActions?.count) == 2
                    }

                    describe("the first action") {
                        describe("for an unread article") {
                            beforeEach {
                                action = previewActions?.first as? UIPreviewAction

                                expect(action?.title).to(equal("Mark Read"))
                                action?.handler(action!, viewController!)
                            }

                            it("marks the article as read") {
                                guard let call = articleService.markArticleAsReadCalls.last else {
                                    fail("Didn't call ArticleService to mark article as read")
                                    return
                                }
                                expect(call.article) == articles.first
                                expect(call.read) == true
                            }

                            context("when the articleService successfully marks the article as read") {
                                var updatedArticle: Article!
                                beforeEach {
                                    guard let article = articles.first else { fail("No articles - can't happen"); return }
                                    updatedArticle = Article(
                                        title: article.title,
                                        link: article.link,
                                        summary: article.summary,
                                        authors: article.authors,
                                        published: article.published,
                                        updatedAt: article.updatedAt,
                                        identifier: article.identifier,
                                        content: article.content,
                                        read: true,
                                        synced: article.synced,
                                        feed: article.feed,
                                        flags: article.flags
                                    )
                                    articleService.markArticleAsReadPromises.last?.resolve(.success(
                                        updatedArticle
                                        ))
                                }

                                it("Updates the articles in the controller to reflect that") {
                                    expect(subject.articles.first).to(equal(updatedArticle))
                                }
                            }

                            context("when the articleService fails to mark the article as read") {
                                xit("presents a banner indicates that a failure happened") {
                                    fail("Not Implemented")
                                }
                            }
                        }

                        describe("for a read article") {
                            beforeEach {
                                let rect = subject.tableView.rectForRow(at: IndexPath(row: 2, section: 1))
                                let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                                viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                                previewActions = viewController?.previewActionItems
                                action = previewActions?.first as? UIPreviewAction

                                expect(action?.title).to(equal("Mark Unread"))
                                action?.handler(action!, viewController!)
                            }

                            it("marks the article as unread") {
                                guard let call = articleService.markArticleAsReadCalls.last else {
                                    fail("Didn't call ArticleService to mark article as read/unread")
                                    return
                                }
                                expect(call.article) == articles[2]
                                expect(call.read) == false
                            }

                            context("when the articleService successfully marks the article as read") {
                                var updatedArticle: Article!
                                beforeEach {
                                    guard let article = articles.first else { fail("No articles - can't happen"); return }
                                    updatedArticle = Article(
                                        title: article.title,
                                        link: article.link,
                                        summary: article.summary,
                                        authors: article.authors,
                                        published: article.published,
                                        updatedAt: article.updatedAt,
                                        identifier: article.identifier,
                                        content: article.content,
                                        read: false,
                                        synced: article.synced,
                                        feed: article.feed,
                                        flags: article.flags
                                    )
                                    articleService.markArticleAsReadPromises.last?.resolve(.success(
                                        updatedArticle
                                        ))
                                }

                                it("Updates the articles in the controller to reflect that") {
                                    expect(subject.articles.first).to(equal(updatedArticle))
                                }
                            }

                            context("when the articleService fails to mark the article as read") {
                                xit("presents a banner indicates that a failure happened") {
                                    fail("Not Implemented")
                                }
                            }
                        }
                    }

                    describe("the last action") {
                        beforeEach {
                            action = previewActions?.last as? UIPreviewAction
                        }

                        it("states that it deletes the article") {
                            expect(action?.title) == "Delete"
                        }

                        describe("tapping it") {
                            beforeEach {
                                action?.handler(action!, viewController!)
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

                                    alert.actions.first?.handler?(alert.actions.first!)
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

                                    alert.actions.last?.handler?(alert.actions.last!)
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
                }

                describe("committing that view controller") {
                    beforeEach {
                        if let vc = viewController {
                            subject.previewingContext(viewControllerPreviewing, commit: vc)
                        }
                    }

                    it("pushes the view controller") {
                        expect(navigationController.topViewController).to(beIdenticalTo(viewController))
                    }

                    it("marks the article as read") {
                        guard let call = articleService.markArticleAsReadCalls.last else {
                            fail("Didn't call ArticleService to mark article as read")
                            return
                        }
                        expect(call.article) == articles[0]
                        expect(call.read) == true
                    }

                    context("when the articleService successfully marks the article as read") {
                        var updatedArticle: Article!
                        beforeEach {
                            guard let article = articles.first else { fail("No articles - can't happen"); return }
                            updatedArticle = Article(
                                title: article.title,
                                link: article.link,
                                summary: article.summary,
                                authors: article.authors,
                                published: article.published,
                                updatedAt: article.updatedAt,
                                identifier: article.identifier,
                                content: article.content,
                                read: true,
                                synced: article.synced,
                                feed: article.feed,
                                flags: article.flags
                            )
                            articleService.markArticleAsReadPromises.last?.resolve(.success(
                                updatedArticle
                            ))
                        }

                        it("Updates the articles in the controller to reflect that") {
                            expect(subject.articles.first).to(equal(updatedArticle))
                        }
                    }

                    context("when the articleService fails to mark the article as read") {
                        xit("presents a banner indicates that a failure happened") {
                            fail("Not Implemented")
                        }
                    }
                }
            }
        }

        describe("the table") {
            it("has 2 sections") {
                subject.view.layoutIfNeeded()
                subject.feed = feed

                expect(subject.tableView.numberOfSections) == 2
            }

            it("does not allow multiselection") {
                subject.view.layoutIfNeeded()
                subject.feed = feed

                expect(subject.tableView.allowsMultipleSelection) == false
            }

            it("allows multiselection if the delegate says so") {
                let delegate = FakeArticleListControllerDelegate()
                delegate.articleListControllerCanSelectMultipleArticlesReturns(true)
                delegate.articleListControllecCanEditArticleReturns(false)
                subject.delegate = delegate
                subject.view.layoutIfNeeded()
                subject.feed = feed

                expect(subject.tableView.allowsMultipleSelection) == true
            }

            describe("the first section") {
                context("when a feed is backing the list") {
                    beforeEach {
                        subject.view.layoutIfNeeded()

                        subject.feed = feed
                        subject.tableView.reloadData()
                    }

                    it("has 1 cell in the first section of the tableView") {
                        expect(subject.tableView.numberOfRows(inSection: 0)) == 1
                    }

                    describe("that cell") {
                        var cell: ArticleListHeaderCell?

                        beforeEach {
                            feed.summary = "summary"
                            cell = subject.tableView.visibleCells.first as? ArticleListHeaderCell
                            expect(cell).toNot(beNil())
                        }

                        it("is configured with the theme repository") {
                            expect(cell?.themeRepository).to(beIdenticalTo(themeRepository))
                        }

                        it("is configured with the feed") {
                            expect(cell?.summary.text) == feed.displaySummary
                        }

                        it("has no edit actions") {
                            expect(subject.tableView(subject.tableView, editActionsForRowAt: IndexPath(row: 0, section: 0))).to(beNil())
                        }

                        it("does nothing when tapped") {
                            subject.tableView(subject.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
                            expect(navigationController.topViewController).to(beIdenticalTo(subject))
                        }
                    }
                }

                context("when a feed without a description or image is backing the list") {
                    beforeEach {
                        subject.view.layoutIfNeeded()

                        subject.feed = Feed(title: "Title", url: URL(string: "https://example.com")!, summary: "",
                                            tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                        subject.tableView.reloadData()
                    }

                    it("has 0 cells in the first section of the tableView") {
                        expect(subject.tableView.numberOfRows(inSection: 0)) == 0
                    }
                }

                context("when a feed is not backing the list") {
                    beforeEach {
                        subject.view.layoutIfNeeded()

                        subject.feed = nil
                        subject.tableView.reloadData()
                    }
                    
                    it("has 0 cells in the first section of the tableView") {
                        expect(subject.tableView.numberOfRows(inSection: 0)) == 0
                    }
                }
            }

            describe("the articles section") {
                beforeEach {
                    subject.feed = feed
                    subject.view.layoutIfNeeded()
                }

                it("has a row for each article") {
                    expect(subject.tableView.numberOfRows(inSection: 1)).to(equal(articles.count))
                }

                describe("the cells") {
                    context("when a delegate is set") {
                        var delegate: FakeArticleListControllerDelegate!
                        beforeEach {
                            delegate = FakeArticleListControllerDelegate()
                            subject.delegate = delegate
                        }

                        it("are only editable if the delegate says so") {
                            let section = 1
                            for row in 0..<subject.tableView.numberOfRows(inSection: section) {
                                let indexPath = IndexPath(row: row, section: section)
                                delegate.articleListControllecCanEditArticleReturns(false)
                                expect(subject.tableView(subject.tableView, canEditRowAt: indexPath)) == false
                                delegate.articleListControllecCanEditArticleReturns(true)
                                expect(subject.tableView(subject.tableView, canEditRowAt: indexPath)) == true
                            }
                        }

                        describe("when tapped (and the delegate says not to show article view") {
                            let indexPath = IndexPath(row: 1, section: 1)
                            beforeEach {
                                delegate.articleListControllerShouldShowArticleViewReturns(false)
                                subject.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                                subject.tableView(subject.tableView, didSelectRowAt: indexPath)
                            }

                            it("nothing should happen") {
                                expect(navigationController.topViewController).to(beIdenticalTo(subject))
                            }

                            it("doesn't deselect the tapped article") {
                                expect(subject.tableView.indexPathsForSelectedRows?.contains(indexPath)) == true
                            }
                        }

                        describe("when tapped (and the delegate says to show the article view)") {
                            beforeEach {
                                delegate.articleListControllerShouldShowArticleViewReturns(true)
                                subject.tableView(subject.tableView, didSelectRowAt: IndexPath(row: 1, section: 1))
                            }

                            it("should navigate to an ArticleViewController") {
                                expect(navigationController.topViewController).to(beAnInstanceOf(ArticleViewController.self))
                                if let articleController = navigationController.topViewController as? ArticleViewController {
                                    expect(articleController.article).to(equal(articles[1]))
                                }
                            }
                        }
                    }

                    context("without a delegate") {
                        it("is editable") {
                            let section = 1
                            for row in 0..<subject.tableView.numberOfRows(inSection: section) {
                                let indexPath = IndexPath(row: row, section: section)
                                expect(subject.tableView(subject.tableView, canEditRowAt: indexPath)) == true
                            }
                        }

                        it("has 2 edit actions") {
                            let section = 1
                            for row in 0..<subject.tableView.numberOfRows(inSection: section) {
                                let indexPath = IndexPath(row: row, section: section)
                                expect(subject.tableView(subject.tableView, editActionsForRowAt: indexPath)?.count).to(equal(2))
                            }
                        }

                        describe("the edit actions") {
                            describe("the first action") {
                                var action: UITableViewRowAction! = nil
                                let indexPath = IndexPath(row: 0, section: 1)

                                beforeEach {
                                    action = subject.tableView(subject.tableView, editActionsForRowAt: indexPath)?.first
                                }

                                it("states that it deletes the article") {
                                    expect(action?.title) == "Delete"
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action.handler?(action, indexPath)
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

                                            alert.actions.first?.handler?(alert.actions.first!)
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

                                            alert.actions.last?.handler?(alert.actions.last!)
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
                                beforeEach {
                                    let indexPath = IndexPath(row: 0, section: 1)
                                    guard let markRead = subject.tableView(subject.tableView, editActionsForRowAt: indexPath)?.last else {
                                        fail("No mark read edit action")
                                        return
                                    }

                                    expect(markRead.title).to(equal("Mark\nRead"))
                                    markRead.handler?(markRead, indexPath)
                                }

                                it("marks the article as read with the second action item") {
                                    guard let call = articleService.markArticleAsReadCalls.last else {
                                        fail("Didn't call ArticleService to mark article as read")
                                        return
                                    }
                                    expect(call.article) == articles.first
                                    expect(call.read) == true
                                }

                                context("when the articleService successfully marks the article as read") {
                                    var updatedArticle: Article!
                                    beforeEach {
                                        guard let article = articles.first else { fail("No articles - can't happen"); return }
                                        updatedArticle = Article(
                                            title: article.title,
                                            link: article.link,
                                            summary: article.summary,
                                            authors: article.authors,
                                            published: article.published,
                                            updatedAt: article.updatedAt,
                                            identifier: article.identifier,
                                            content: article.content,
                                            read: true,
                                            synced: article.synced,
                                            feed: article.feed,
                                            flags: article.flags
                                        )
                                        articleService.markArticleAsReadPromises.last?.resolve(.success(
                                            updatedArticle
                                        ))
                                    }

                                    it("Updates the articles in the controller to reflect that") {
                                        expect(subject.articles.first).to(equal(updatedArticle))
                                    }
                                }

                                context("when the articleService fails to mark the article as read") {
                                    xit("presents a banner indicates that a failure happened") {
                                        fail("Not Implemented")
                                    }
                                }
                            }

                            describe("for a read article") {
                                beforeEach {
                                    let indexPath = IndexPath(row: 2, section: 1)
                                    guard let markRead = subject.tableView(subject.tableView, editActionsForRowAt: indexPath)?.last else {
                                        fail("No mark unread edit action")
                                        return
                                    }

                                    expect(markRead.title).to(equal("Mark\nUnread"))
                                    markRead.handler?(markRead, indexPath)
                                }

                                it("marks the article as unread with the second action item") {
                                    guard let call = articleService.markArticleAsReadCalls.last else {
                                        fail("Didn't call ArticleService to mark article as read")
                                        return
                                    }
                                    expect(call.article) == articles[2]
                                    expect(call.read) == false
                                }

                                context("when the articleService successfully marks the article as read") {
                                    var updatedArticle: Article!
                                    beforeEach {
                                        guard let article = articles.first else { fail("No articles - can't happen"); return }
                                        updatedArticle = Article(
                                            title: article.title,
                                            link: article.link,
                                            summary: article.summary,
                                            authors: article.authors,
                                            published: article.published,
                                            updatedAt: article.updatedAt,
                                            identifier: article.identifier,
                                            content: article.content,
                                            read: false,
                                            synced: article.synced,
                                            feed: article.feed,
                                            flags: article.flags
                                        )
                                        articleService.markArticleAsReadPromises.last?.resolve(.success(
                                            updatedArticle
                                            ))
                                    }

                                    it("Updates the articles in the controller to reflect that") {
                                        expect(Array(subject.articles)[2]).to(equal(updatedArticle))
                                    }
                                }

                                context("when the articleService fails to mark the article as read") {
                                    xit("presents a banner indicates that a failure happened") {
                                        fail("Not Implemented")
                                    }
                                }
                            }
                        }
                        
                        describe("when tapped") {
                            beforeEach {
                                subject.tableView(subject.tableView, didSelectRowAt: IndexPath(row: 1, section: 1))
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
}
