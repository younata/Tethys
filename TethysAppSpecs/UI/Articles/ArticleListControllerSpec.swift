import Quick
import Nimble
@testable import Tethys
@testable import TethysKit
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
    return Article(title: "article \(publishedOffset)", link: URL(string: "http://example.com")!, summary: "",
                   authors: [Author(name: "Rachel", email: nil)], published: publishDate, updatedAt: updatedDate,
                   identifier: "\(publishedOffset)", content: "", read: read)
}

class ArticleListControllerSpec: QuickSpec {
    override func spec() {
        var mainQueue: FakeOperationQueue!
        var feed: Feed!
        var subject: ArticleListController!
        var navigationController: UINavigationController!
        var articles: [Article] = []

        var articleUseCase: FakeArticleUseCase!

        var feedService: FakeFeedService!
        var articleService: FakeArticleService!
        var themeRepository: ThemeRepository!
        var articleCellController: FakeArticleCellController!

        beforeEach {
            mainQueue = FakeOperationQueue()

            articleUseCase = FakeArticleUseCase()
            articleUseCase.readArticleReturns("hello")

            themeRepository = ThemeRepository(userDefaults: nil)

            publishedOffset = 0

            feed = Feed(title: "", url: URL(string: "https://example.com")!, summary: "hello world", tags: [], unreadCount: 0, image: nil)

            let d = fakeArticle(feed: feed)
            let c = fakeArticle(feed: feed, read: true)
            let b = fakeArticle(feed: feed, isUpdated: true)
            let a = fakeArticle(feed: feed)
            articles = [a, b, c, d]

            feedService = FakeFeedService()
            articleService = FakeArticleService()
            articleCellController = FakeArticleCellController()

            subject = ArticleListController(
                feed: feed,
                feedService: feedService,
                articleService: articleService,
                themeRepository: themeRepository,
                articleCellController: articleCellController,
                articleViewController: { article in articleViewControllerFactory(article: article, articleUseCase: articleUseCase) }
            )

            navigationController = UINavigationController(rootViewController: subject)

            subject.view.layoutIfNeeded()
        }

        it("requests the articles from the cell") {
            expect(feedService.articlesOfFeedCalls).to(equal([feed]))
        }

        it("dismisses the keyboard upon drag") {
            expect(subject.tableView.keyboardDismissMode).to(equal(UIScrollView.KeyboardDismissMode.onDrag))
        }

        it("hides the toolbar") {
            expect(navigationController.isToolbarHidden).to(beTruthy())
        }

        describe("listening to theme repository updates") {
            beforeEach {
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
                expect(convertFromOptionalNSAttributedStringKeyDictionary(subject.navigationController?.navigationBar.titleTextAttributes) as? [String: UIColor]) == [convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): themeRepository.textColor]
            }
        }

        describe("when the request succeeds") {
            beforeEach {
                feedService.articlesOfFeedPromises.last?.resolve(.success(AnyCollection(articles)))
            }

            describe("the bar button items") {
                it("displays 3 items") {
                    expect(subject.navigationItem.rightBarButtonItems).to(haveCount(3))
                }

                describe("the first item") {
                    var item: UIBarButtonItem?

                    beforeEach {
                        item = subject.navigationItem.rightBarButtonItems?.first
                    }

                    it("is the edit button") {
                        expect(item) == subject.editButtonItem
                    }
                }

                describe("the second item") {
                    var item: UIBarButtonItem?

                    beforeEach {
                        guard subject.navigationItem.rightBarButtonItems?.count == 3 else {
                            item = nil
                            return
                        }
                        item = subject.navigationItem.rightBarButtonItems?[1]
                    }

                    describe("when tapped") {
                        beforeEach {
                            item?.tap()
                        }

                        it("presents a share sheet") {
                            expect(subject.presentedViewController).to(beAnInstanceOf(URLShareSheet.self))
                        }

                        it("configures the share sheet with the url") {
                            guard let shareSheet = subject.presentedViewController as? URLShareSheet else {
                                fail("No share sheet presented")
                                return
                            }
                            expect(shareSheet.url) == feed.url
                            expect(shareSheet.themeRepository) == themeRepository
                            expect(shareSheet.activityItems as? [URL]) == [feed.url]
                        }
                    }
                }

                describe("the third item") {
                    var item: UIBarButtonItem?

                    beforeEach {
                        item = subject.navigationItem.rightBarButtonItems?.last
                    }

                    describe("when tapped") {
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
                            expect(feedService.readAllOfFeedCalls) == [feed]
                        }

                        describe("when the mark read promise succeeds") {
                            beforeEach {
                                feedService.readAllOfFeedPromises.last?.resolve(.success(()))
                            }

                            it("removes the indicator") {
                                let indicator = subject.view.subviews.filter {
                                    return $0.isKind(of: ActivityIndicator.classForCoder())
                                    }.first
                                expect(indicator).to(beNil())
                            }

                            it("refreshes the articles") {
                                expect(feedService.articlesOfFeedCalls).to(haveCount(2))
                                expect(feedService.articlesOfFeedCalls.last).to(equal(feed))
                            }

                            describe("when the articles request succeeds") {
                                let updatedArticles = [
                                    articleFactory(title: "1"),
                                    articleFactory(title: "2"),
                                    articleFactory(title: "3"),
                                    ]
                                var oldConfigureCalls: Int = 0
                                beforeEach {
                                    oldConfigureCalls = articleCellController.configureCalls.count
                                    feedService.articlesOfFeedPromises.last?.resolve(.success(AnyCollection(updatedArticles)))
                                }

                                it("refreshes the tableView with the articles") {
                                    expect(articleCellController.configureCalls.count - oldConfigureCalls).to(equal(3))

                                    let calls = articleCellController.configureCalls.suffix(3)

                                    expect(calls.map { $0.article }).to(equal(updatedArticles))
                                }
                            }
                        }

                        describe("when the mark read promise fails") {
                            beforeEach {
                                feedService.readAllOfFeedPromises.last?.resolve(.failure(.database(.unknown)))
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

            describe("force pressing an article cell") {
                var viewControllerPreviewing: FakeUIViewControllerPreviewing! = nil
                let indexPath = IndexPath(row: 0, section: 1)
                var viewController: UIViewController? = nil

                beforeEach {
                    viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

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
                                    updatedArticle = articleFactory()
                                    articleService.markArticleAsReadPromises.last?.resolve(.success(updatedArticle))
                                }

                                it("Updates the articles in the controller to reflect that") {
                                    expect(subject.articles.first).to(equal(updatedArticle))
                                }
                            }

                            context("when the articleService fails to mark the article as read") {
                                beforeEach {
                                    articleService.markArticleAsReadPromises.last?.resolve(.failure(.database(.unknown)))
                                }

                                it("shows an alert box") {
                                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                    if let alert = subject.presentedViewController as? UIAlertController {
                                        expect(alert.title) == "Error saving article"
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
                                    updatedArticle = articleFactory()
                                    articleService.markArticleAsReadPromises.last?.resolve(.success(updatedArticle))
                                }

                                it("Updates the articles in the controller to reflect that") {
                                    expect(Array(subject.articles)[2]).to(equal(updatedArticle))
                                }
                            }

                            context("when the articleService fails to mark the article as read") {
                                beforeEach {
                                    articleService.markArticleAsReadPromises.last?.resolve(.failure(.database(.unknown)))
                                }

                                it("shows an alert box") {
                                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                    if let alert = subject.presentedViewController as? UIAlertController {
                                        expect(alert.title) == "Error saving article"
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
                                expect(articleService.removeArticleCalls).to(beEmpty())
                            }

                            it("presents an alert asking for confirmation that the user wants to do this") {
                                expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                guard let alert = subject.presentedViewController as? UIAlertController else { return }
                                expect(alert.preferredStyle) == UIAlertController.Style.alert
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
                                    expect(articleService.removeArticleCalls.last).to(equal(articles.first))
                                }

                                it("dismisses the alert") {
                                    expect(subject.presentedViewController).to(beNil())
                                }

                                xit("shows a spinner while we wait to delete the article") {
                                    fail("Implement me!")
                                }

                                context("when the delete operation succeeds") {
                                    beforeEach {
                                        articleService.removeArticlePromises.last?.resolve(.success(()))
                                    }

                                    it("removes the article from the list") {
                                        expect(Array(subject.articles)).toNot(contain(articles[0]))
                                    }
                                }

                                context("when the delete operation fails") {
                                    beforeEach {
                                        articleService.removeArticlePromises.last?.resolve(.failure(TethysError.database(.unknown)))
                                    }

                                    it("shows an alert box") {
                                        expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                        if let alert = subject.presentedViewController as? UIAlertController {
                                            expect(alert.title) == "Error deleting article"
                                            expect(alert.message) == "Unknown Database Error"
                                            expect(alert.actions.count) == 1
                                            if let action = alert.actions.first {
                                                expect(action.title) == "Ok"
                                                action.handler?(action)
                                                expect(subject.presentedViewController).to(beNil())
                                            }
                                        }
                                    }

                                    it("keeps the article from the list") {
                                        expect(Array(subject.articles)).to(contain(articles[0]))
                                    }
                                }
                            }

                            describe("tapping 'Cancel'") {
                                beforeEach {
                                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                    guard let alert = subject.presentedViewController as? UIAlertController else { return }

                                    alert.actions.last?.handler?(alert.actions.last!)
                                }

                                it("does not delete the article") {
                                    expect(articleService.removeArticleCalls).to(beEmpty())
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
                            updatedArticle = articleFactory()
                            articleService.markArticleAsReadPromises.last?.resolve(.success(updatedArticle))
                        }

                        it("Updates the articles in the controller to reflect that") {
                            expect(subject.articles.first).to(equal(updatedArticle))
                        }
                    }

                    context("when the articleService fails to mark the article as read") {
                        beforeEach {
                            articleService.markArticleAsReadPromises.last?.resolve(.failure(.database(.unknown)))
                        }

                        it("shows an alert box") {
                            expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                            if let alert = subject.presentedViewController as? UIAlertController {
                                expect(alert.title) == "Error saving article"
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

            describe("the table") {
                it("has 2 sections") {
                    expect(subject.tableView.numberOfSections) == 2
                }

                it("does not allow multiselection") {
                    expect(subject.tableView.allowsMultipleSelection) == false
                }

                describe("the first section") {
                    func itShowsTheFeedCell() {
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

                            it("configures the image") {
                                if let image = feed.image {
                                    expect(cell?.iconView.image) == image
                                } else {
                                    expect(cell?.iconView.image).to(beNil())
                                }
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

                    context("if the feed has a summary and an image") {
                        beforeEach {
                            feed.image = Image(named: "GrayIcon")
                            feed.summary = "a summary"
                            subject.tableView.reloadData()
                        }

                        itShowsTheFeedCell()
                    }

                    context("if the feed only has a summary") {
                        beforeEach {
                            feed.image = nil
                            feed.summary = "a summary"
                            subject.tableView.reloadData()
                        }

                        itShowsTheFeedCell()
                    }

                    context("if the feed only has an image") {
                        beforeEach {
                            feed.image = Image(named: "GrayIcon")
                            feed.summary = ""
                            subject.tableView.reloadData()
                        }
                        itShowsTheFeedCell()
                    }

                    context("if the feed has neither summary nor image") {
                        beforeEach {
                            feed.image = nil
                            feed.summary = ""
                            subject.tableView.reloadData()
                        }

                        it("has 0 cells in the first section of the tableView") {
                            expect(subject.tableView.numberOfRows(inSection: 0)) == 0
                        }
                    }
                }

                describe("the articles section") {
                    it("has a row for each article") {
                        expect(subject.tableView.numberOfRows(inSection: 1)).to(equal(articles.count))
                    }

                    describe("the cells") {
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
                                var action: UITableViewRowAction? = nil
                                let indexPath = IndexPath(row: 0, section: 1)

                                beforeEach {
                                    guard subject.tableView.numberOfRows(inSection: indexPath.section) > indexPath.row else {
                                        fail("No row for \(indexPath)")
                                        return
                                    }
                                    action = subject.tableView(subject.tableView, editActionsForRowAt: indexPath)?.first
                                }

                                it("states that it deletes the article") {
                                    expect(action?.title) == "Delete"
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action?.handler?(action!, indexPath)
                                    }

                                    it("does not yet delete the article") {
                                        expect(articleService.removeArticleCalls).to(beEmpty())
                                    }

                                    it("presents an alert asking for confirmation that the user wants to do this") {
                                        expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                        guard let alert = subject.presentedViewController as? UIAlertController else { return }
                                        expect(alert.preferredStyle) == UIAlertController.Style.alert
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
                                            expect(articleService.removeArticleCalls.last) == articles.first
                                        }

                                        it("dismisses the alert") {
                                            expect(subject.presentedViewController).to(beNil())
                                        }

                                        xit("shows a spinner while we wait to delete the article") {
                                            fail("Implement me!")
                                        }

                                        context("when the delete operation succeeds") {
                                            beforeEach {
                                                articleService.removeArticlePromises.last?.resolve(.success(()))
                                            }

                                            it("removes the article from the list") {
                                                expect(Array(subject.articles)).toNot(contain(articles[0]))
                                            }
                                        }

                                        context("when the delete operation fails") {
                                            beforeEach {
                                                articleService.removeArticlePromises.last?.resolve(.failure(TethysError.database(.unknown)))
                                            }

                                            it("shows an alert box") {
                                                expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                                if let alert = subject.presentedViewController as? UIAlertController {
                                                    expect(alert.title) == "Error deleting article"
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

                                    describe("tapping 'Cancel'") {
                                        beforeEach {
                                            expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                            guard let alert = subject.presentedViewController as? UIAlertController else { return }

                                            alert.actions.last?.handler?(alert.actions.last!)
                                        }

                                        it("does not delete the article") {
                                            expect(articleService.removeArticleCalls).to(beEmpty())
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
                                    guard subject.tableView.numberOfRows(inSection: indexPath.section) > indexPath.row else {
                                        fail("No row for \(indexPath)")
                                        return
                                    }
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
                                        updatedArticle = articleFactory()
                                        articleService.markArticleAsReadPromises.last?.resolve(.success(updatedArticle))
                                    }

                                    it("Updates the articles in the controller to reflect that") {
                                        expect(subject.articles.first).to(equal(updatedArticle))
                                    }
                                }

                                context("when the articleService fails to mark the article as read") {
                                    beforeEach {
                                        articleService.markArticleAsReadPromises.last?.resolve(.failure(.database(.unknown)))
                                    }

                                    it("shows an alert box") {
                                        expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                        if let alert = subject.presentedViewController as? UIAlertController {
                                            expect(alert.title) == "Error saving article"
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

                            describe("for a read article") {
                                beforeEach {
                                    let indexPath = IndexPath(row: 2, section: 1)
                                    guard subject.tableView.numberOfRows(inSection: indexPath.section) > indexPath.row else {
                                        fail("No row for \(indexPath)")
                                        return
                                    }
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
                                        updatedArticle = articleFactory(read: true)
                                        articleService.markArticleAsReadPromises.last?.resolve(.success(updatedArticle))
                                    }

                                    it("Updates the articles in the controller to reflect that") {
                                        expect(Array(subject.articles)[2]).to(equal(updatedArticle))
                                    }
                                }

                                context("when the articleService fails to mark the article as read") {
                                    beforeEach {
                                        articleService.markArticleAsReadPromises.last?.resolve(.failure(.database(.unknown)))
                                    }

                                    it("shows an alert box") {
                                        expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                        if let alert = subject.presentedViewController as? UIAlertController {
                                            expect(alert.title) == "Error saving article"
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

                        describe("when tapped") {
                            beforeEach {
                                let indexPath = IndexPath(row: 1, section: 1)
                                guard subject.tableView.numberOfRows(inSection: indexPath.section) > indexPath.row else {
                                    fail("No row for \(indexPath)")
                                    return
                                }
                                subject.tableView(subject.tableView, didSelectRowAt: indexPath)
                            }

                            it("should navigate to an ArticleViewController") {
                                expect(navigationController.topViewController).to(beAnInstanceOf(ArticleViewController.self))
                                if let articleController = navigationController.topViewController as? ArticleViewController {
                                    expect(articleController.article).to(equal(articles[1]))
                                }
                            }

                            it("marks the article as read") {
                                expect(articleService.markArticleAsReadCalls.last?.article).to(equal(articles[1]))
                            }

                            describe("if the mark article as read call fails") {
                                beforeEach {
                                    articleService.markArticleAsReadPromises.last?.resolve(.failure(.database(.unknown)))
                                }

                                it("shows an alert box") {
                                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                    if let alert = subject.presentedViewController as? UIAlertController {
                                        expect(alert.title) == "Error saving article"
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
            }
        }

        describe("when the request fails") {
            beforeEach {
                feedService.articlesOfFeedPromises.last?.resolve(.failure(.database(.unknown)))
            }

            it("shows an alert box") {
                expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                if let alert = subject.presentedViewController as? UIAlertController {
                    expect(alert.title) == "Unable to retrieve articles"
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

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromOptionalNSAttributedStringKeyDictionary(_ input: [NSAttributedString.Key: Any]?) -> [String: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}
