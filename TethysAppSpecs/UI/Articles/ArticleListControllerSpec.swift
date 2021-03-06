import Quick
import Nimble
@testable import Tethys
@testable import TethysKit
import UIKit

private var publishedOffset = -1
func fakeArticle(feed: Feed, isUpdated: Bool = false, read: Bool = false) -> Article {
    publishedOffset += 1
    return articleFactory(title: "article \(publishedOffset)", link: URL(string: "http://example.com")!, summary: "",
                          authors: [Author(name: "Rachel", email: nil)], identifier: "\(publishedOffset)", content: "",
                          read: read)
}

class ArticleListControllerSpec: QuickSpec {
    override func spec() {
        var mainQueue: FakeOperationQueue!
        var feed: Feed!
        var subject: ArticleListController!
        var navigationController: UINavigationController!
        var articles: [Article] = []

        var articleUseCase: FakeArticleUseCase!

        var feedCoordinator: FakeFeedCoordinator!
        var articleCoordinator: FakeArticleCoordinator!
        var notificationCenter: NotificationCenter!
        var articleCellController: FakeArticleCellController!
        var messenger: FakeMessenger!

        var recorder: NotificationRecorder!

        beforeEach {
            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            articleUseCase = FakeArticleUseCase()
            articleUseCase.readArticleReturns("hello")

            notificationCenter = NotificationCenter()

            publishedOffset = 0

            feed = Feed(title: "", url: URL(string: "https://example.com")!, summary: "hello world", tags: [], unreadCount: 0, image: nil)

            let d = fakeArticle(feed: feed)
            let c = fakeArticle(feed: feed, read: true)
            let b = fakeArticle(feed: feed, isUpdated: true)
            let a = fakeArticle(feed: feed)
            articles = [a, b, c, d]

            feedCoordinator = FakeFeedCoordinator()
            articleCoordinator = FakeArticleCoordinator()
            articleCellController = FakeArticleCellController()

            messenger = FakeMessenger()

            subject = ArticleListController(
                feed: feed,
                mainQueue: mainQueue,
                messenger: messenger,
                feedCoordinator: feedCoordinator,
                articleCoordinator: articleCoordinator,
                notificationCenter: notificationCenter,
                articleCellController: articleCellController,
                articleViewController: { article in articleViewControllerFactory(article: article, articleUseCase: articleUseCase) }
            )

            navigationController = UINavigationController(rootViewController: subject)

            subject.view.layoutIfNeeded()

            recorder = NotificationRecorder()
            notificationCenter.addObserver(recorder!, selector: #selector(NotificationRecorder.received(notification:)),
                                           name: Notifications.reloadUI, object: subject)
        }

        it("requests the articles from the cell") {
            expect(feedCoordinator.articlesOfFeedCalls).to(equal([feed]))
        }

        it("dismisses the keyboard upon drag") {
            expect(subject.tableView.keyboardDismissMode).to(equal(UIScrollView.KeyboardDismissMode.onDrag))
        }

        it("hides the toolbar") {
            expect(navigationController.isToolbarHidden).to(beTruthy())
        }

        describe("theming") {
            beforeEach {
                subject.viewWillAppear(false)
            }

            it("sets the tableView's theme") {
                expect(subject.tableView.backgroundColor).to(equal(Theme.backgroundColor))
                expect(subject.tableView.separatorColor).to(equal(Theme.separatorColor))
            }
        }

        describe("the table header") {
            func resetSubject() {
                subject = ArticleListController(
                    feed: feed,
                    mainQueue: mainQueue,
                    messenger: messenger,
                    feedCoordinator: feedCoordinator,
                    articleCoordinator: articleCoordinator,
                    notificationCenter: notificationCenter,
                    articleCellController: articleCellController,
                    articleViewController: { article in articleViewControllerFactory(article: article, articleUseCase: articleUseCase) }
                )

                navigationController = UINavigationController(rootViewController: subject)

                subject.view.layoutIfNeeded()
                notificationCenter.addObserver(recorder!, selector: #selector(NotificationRecorder.received(notification:)),
                name: Notifications.reloadUI, object: subject)
            }

            func itShowsTheFeedHeader(_ line: UInt = #line) {
                it("sets the tableView's headerview") {
                    expect(subject.tableView.tableHeaderView, line: line).to(beAKindOf(ArticleListHeaderView.self))
                }

                describe("that view") {
                    var headerView: ArticleListHeaderView?

                    beforeEach {
                        headerView = subject.tableView.tableHeaderView as? ArticleListHeaderView
                        expect(headerView, line: line).toNot(beNil())
                    }

                    it("configures the image") {
                        if let image = feed.image {
                            expect(headerView?.iconView.image, line: line).to(be(image))
                        } else {
                            expect(headerView?.iconView.image, line: line).to(beNil())
                        }
                    }

                    it("is configured for accessibility") {
                        expect(headerView?.isAccessibilityElement, line: line).to(beTrue())
                        expect(headerView?.accessibilityLabel, line: line).to(equal("Feed summary"))
                        expect(headerView?.accessibilityValue, line: line).to(equal(feed.displaySummary))
                        expect(headerView?.accessibilityTraits, line: line).to(equal([.staticText]))
                    }

                    it("is configured with the feed") {
                        expect(headerView?.summary.text, line: line).to(equal(feed.displaySummary))
                    }
                }
            }

            context("if the feed has a summary and an image") {
                beforeEach {
                    feed.image = Image(named: "GrayIcon")
                    feed.summary = "a summary"
                    resetSubject()
                }

                itShowsTheFeedHeader()
            }

            context("if the feed only has a summary") {
                beforeEach {
                    feed.image = nil
                    feed.summary = "a summary"
                    resetSubject()
                }

                itShowsTheFeedHeader()
            }

            context("if the feed only has an image") {
                beforeEach {
                    feed.image = Image(named: "GrayIcon")
                    feed.summary = ""
                    resetSubject()
                }

                itShowsTheFeedHeader()
            }

            context("if the feed has neither summary nor image") {
                beforeEach {
                    feed.image = nil
                    feed.summary = ""
                    resetSubject()
                }

                it("does not show a feed header") {
                    expect(subject.tableView.tableHeaderView).to(beNil())
                }
            }
        }

        func itTellsTheUserAboutTheError(title: String, message: String, line: UInt = #line) {
            it("shows an alert") {
                guard let error = messenger.errorCalls.last else {
                    return expect(messenger.errorCalls).to(haveCount(1))
                }
                expect(error.title, line: line).to(equal(title))
                expect(error.message, line: line).to(equal(message))
            }
        }

        describe("when the request succeeds") {
            beforeEach {
                feedCoordinator.articlesOfFeedPublishers.last?.update(with: .success(AnyCollection(articles)))
            }

            describe("the bar button items") {
                it("displays 2 items") {
                    expect(subject.navigationItem.rightBarButtonItems).to(haveCount(2))
                }

                describe("the first item") {
                    var item: UIBarButtonItem?

                    beforeEach {
                        item = subject.navigationItem.rightBarButtonItems?.first
                    }

                    it("is configured for accessibility") {
                        expect(item?.isAccessibilityElement).to(beTrue())
                        expect(item?.accessibilityTraits).to(equal([.button]))
                        expect(item?.accessibilityLabel).to(equal("Share feed"))
                    }

                    describe("when tapped") {
                        beforeEach {
                            item?.tap()
                        }

                        it("presents a share sheet") {
                            expect(subject.presentedViewController).to(beAnInstanceOf(UIActivityViewController.self))
                        }

                        it("configures the share sheet with the url") {
                            guard let shareSheet = subject.presentedViewController as? UIActivityViewController else {
                                fail("No share sheet presented")
                                return
                            }
                            expect(shareSheet.activityItems as? [URL]).to(equal([feed.url]))
                        }
                    }
                }

                describe("the second item") {
                    var item: UIBarButtonItem?

                    beforeEach {
                        item = subject.navigationItem.rightBarButtonItems?.last
                    }

                    it("is configured for accessibility") {
                        expect(item?.isAccessibilityElement).to(beTrue())
                        expect(item?.accessibilityTraits).to(equal([.button]))
                        expect(item?.accessibilityLabel).to(equal("Mark feed as read"))
                    }

                    describe("when tapped") {
                        beforeEach {
                            item?.tap()
                        }

                        it("shows an indicator that we're doing things") {
                            let indicator = subject.view.subviews.filter {
                                return $0.isKind(of: ActivityIndicator.classForCoder())
                            }.first as? ActivityIndicator
                            expect(indicator?.message).to(equal("Marking Articles as Read"))
                        }

                        it("marks all articles of that feed as read") {
                            expect(feedCoordinator.readAllOfFeedCalls).to(equal([feed]))
                        }

                        describe("when the mark read promise succeeds") {
                            beforeEach {
                                feedCoordinator.readAllOfFeedPromises.last?.resolve(.success(()))
                            }

                            it("removes the indicator") {
                                let indicator = subject.view.subviews.filter {
                                    return $0.isKind(of: ActivityIndicator.classForCoder())
                                    }.first
                                expect(indicator).to(beNil())
                            }

                            it("refreshes the articles") {
                                expect(feedCoordinator.articlesOfFeedCalls).to(haveCount(2))
                                expect(feedCoordinator.articlesOfFeedCalls.last).to(equal(feed))
                            }

                            it("posts a notification telling other things to reload") {
                                expect(recorder.notifications).to(haveCount(1))
                                expect(recorder.notifications.last?.object as? NSObject).to(be(subject))
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
                                    feedCoordinator.articlesOfFeedPublishers.last?.update(with: .success(AnyCollection(updatedArticles)))
                                }

                                it("refreshes the tableView with the articles") {
                                    expect(articleCellController.configureCalls.count - oldConfigureCalls).to(equal(3))

                                    let calls = articleCellController.configureCalls.suffix(3)

                                    expect(calls.map { $0.article }).to(contain(updatedArticles))

                                    expect(subject.tableView.numberOfSections).to(equal(1))
                                    expect(subject.tableView.numberOfRows(inSection: 0)).to(equal(3))
                                }
                            }

                            describe("when the articles request fails") {
                                beforeEach {
                                    feedCoordinator.articlesOfFeedPublishers.last?.update(with: .failure(.unknown))
                                }

                                it("doesn't remove the articles from the feed") {
                                    expect(subject.tableView.numberOfSections).to(equal(1))
                                    expect(subject.tableView.numberOfRows(inSection: 0)).to(equal(4))
                                }

                                itTellsTheUserAboutTheError(title: "Unable to retrieve articles", message: "Unknown Error - please try again")
                            }
                        }

                        describe("when the mark read promise fails") {
                            beforeEach {
                                feedCoordinator.readAllOfFeedPromises.last?.resolve(.failure(.database(.unknown)))
                            }

                            it("removes the indicator") {
                                let indicator = subject.view.subviews.filter {
                                    return $0.isKind(of: ActivityIndicator.classForCoder())
                                    }.first
                                expect(indicator).to(beNil())
                            }

                            itTellsTheUserAboutTheError(title: "Unable to Mark Articles as Read", message: "Unknown Database Error")

                            it("doesn't post a notification") {
                                expect(recorder.notifications).to(beEmpty())
                            }
                        }
                    }
                }
            }

            describe("the table") {
                it("has 1 section") {
                    expect(subject.tableView.numberOfSections).to(equal(1))
                }

                it("does not allow multiselection") {
                    expect(subject.tableView.allowsMultipleSelection).to(equal(false))
                }

                describe("the articles section") {
                    it("has a row for each article") {
                        expect(subject.tableView.numberOfRows(inSection: 0)).to(equal(articles.count))
                    }

                    describe("the cells") {
                        let section = 0
                        it("are editable") {
                            for row in 0..<subject.tableView.numberOfRows(inSection: section) {
                                let indexPath = IndexPath(row: row, section: section)
                                expect(subject.tableView.dataSource?.tableView?(subject.tableView, canEditRowAt: indexPath)).to(beTrue())
                            }
                        }

                        it("have 2 contextual actions") {
                            for row in 0..<subject.tableView.numberOfRows(inSection: section) {
                                let indexPath = IndexPath(row: row, section: section)
                                let swipeActions = subject.tableView.delegate?.tableView?(subject.tableView, trailingSwipeActionsConfigurationForRowAt: indexPath)
                                expect(swipeActions).toNot(beNil())
                                expect(swipeActions?.performsFirstActionWithFullSwipe).to(beTrue())
                                expect(swipeActions?.actions.count).to(equal(2))
                            }
                        }

                        describe("the contextual actions") {
                            var completionHandlerCalls: [Bool] = []

                            beforeEach {
                                completionHandlerCalls = []
                            }
                            describe("the first action") {
                                var action: UIContextualAction? = nil
                                let indexPath = IndexPath(row: 0, section: section)

                                beforeEach {
                                    guard subject.tableView.numberOfRows(inSection: indexPath.section) > indexPath.row else {
                                        fail("No row for \(indexPath)")
                                        return
                                    }
                                    action = subject.tableView.delegate?.tableView?(subject.tableView, trailingSwipeActionsConfigurationForRowAt: indexPath)?.actions.first
                                }

                                it("states that it deletes the article") {
                                    expect(action?.title).to(equal("Delete"))
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action?.handler(action!, subject.tableView.cellForRow(at: indexPath)!) { completionHandlerCalls.append($0) }
                                    }

                                    it("deletes the article") {
                                        expect(articleCoordinator.removeArticleCalls.last).to(equal(articles.first))
                                    }

                                    xit("shows a spinner while we wait to delete the article") {
                                        fail("Implement me!")
                                    }

                                    context("when the delete operation succeeds") {
                                        beforeEach {
                                            articleCoordinator.removeArticlePromises.last?.resolve(.success(()))
                                        }

                                        it("removes the article from the list") {
                                            expect(Array(subject.articles)).toNot(contain(articles[0]))
                                        }

                                        it("calls the completion handler") {
                                            expect(completionHandlerCalls).to(equal([true]))
                                        }
                                    }

                                    context("when the delete operation fails") {
                                        beforeEach {
                                            articleCoordinator.removeArticlePromises.last?.resolve(.failure(TethysError.database(.unknown)))
                                        }

                                        itTellsTheUserAboutTheError(title: "Error deleting article", message: "Unknown Database Error")

                                        it("calls the completion handler") {
                                            expect(completionHandlerCalls).to(equal([false]))
                                        }
                                    }
                                }
                            }

                            describe("the second action") {
                                describe("for an unread article") {
                                    beforeEach {
                                        let indexPath = IndexPath(row: 0, section: section)
                                        guard subject.tableView.numberOfRows(inSection: indexPath.section) > indexPath.row else {
                                            fail("No row for \(indexPath)")
                                            return
                                        }
                                        let action = subject.tableView.delegate?.tableView?(subject.tableView, trailingSwipeActionsConfigurationForRowAt: indexPath)?.actions.last

                                        expect(action?.title).to(equal("Mark\nRead"))
                                        action?.handler(action!, subject.tableView.cellForRow(at: indexPath)!) { completionHandlerCalls.append($0) }
                                    }

                                    it("marks the article as read with the second action item") {
                                        guard let call = articleCoordinator.markArticleAsReadCalls.last else {
                                            fail("Didn't call ArticleService to mark article as read")
                                            return
                                        }
                                        expect(call.article).to(equal(articles.first))
                                        expect(call.read).to(beTrue())
                                    }

                                    context("marks the article as read updates with success") {
                                        var updatedArticle: Article!
                                        beforeEach {
                                            updatedArticle = articleFactory()
                                            articleCoordinator.markArticleAsReadPublishers.last?.update(with: .success(updatedArticle))
                                        }

                                        it("Updates the articles in the controller to reflect that") {
                                            expect(subject.articles.first).to(equal(updatedArticle))
                                        }

                                        it("does not call the completion handler") {
                                            expect(completionHandlerCalls).to(beEmpty())
                                        }

                                        context("if the mark article as read operation updates again with failure") {
                                            beforeEach {
                                                articleCoordinator.markArticleAsReadPublishers.last?.update(with: .failure(.database(.unknown)))
                                            }

                                            itTellsTheUserAboutTheError(title: "Error saving article", message: "Unknown Database Error")

                                            it("does not call the completion handler") {
                                                expect(completionHandlerCalls).to(beEmpty())
                                            }

                                            context("when the mark article as read operation completes") {
                                                beforeEach {
                                                    articleCoordinator.markArticleAsReadPublishers.last?.finish()
                                                }

                                                it("calls the completion handler") {
                                                    expect(completionHandlerCalls).to(equal([false]))
                                                }
                                            }
                                        }

                                        context("when the mark article as read operation completes") {
                                            beforeEach {
                                                articleCoordinator.markArticleAsReadPublishers.last?.finish()
                                            }

                                            it("calls the completion handler") {
                                                expect(completionHandlerCalls).to(equal([true]))
                                            }
                                        }
                                    }

                                    context("when the articleService fails to mark the article as read") {
                                        beforeEach {
                                            articleCoordinator.markArticleAsReadPublishers.last?.update(with: .failure(.database(.unknown)))
                                        }

                                        itTellsTheUserAboutTheError(title: "Error saving article", message: "Unknown Database Error")

                                        it("does not call the completion handler") {
                                            expect(completionHandlerCalls).to(beEmpty())
                                        }

                                        context("if the mark article as read operation updates again with success") {
                                            var updatedArticle: Article!
                                            beforeEach {
                                                updatedArticle = articleFactory()
                                                articleCoordinator.markArticleAsReadPublishers.last?.update(with: .success(updatedArticle))
                                            }

                                            it("Updates the articles in the controller to reflect that") {
                                                expect(subject.articles.first).to(equal(updatedArticle))
                                            }

                                            it("does not call the completion handler") {
                                                expect(completionHandlerCalls).to(beEmpty())
                                            }

                                            context("when the mark article as read operation completes") {
                                                beforeEach {
                                                    articleCoordinator.markArticleAsReadPublishers.last?.finish()
                                                }

                                                it("calls the completion handler") {
                                                    expect(completionHandlerCalls).to(equal([false]))
                                                }
                                            }
                                        }

                                        context("when the mark article as read operation completes") {
                                            beforeEach {
                                                articleCoordinator.markArticleAsReadPublishers.last?.finish()
                                            }

                                            it("calls the completion handler") {
                                                expect(completionHandlerCalls).to(equal([false]))
                                            }
                                        }
                                    }
                                }

                                describe("for a read article") {
                                    beforeEach {
                                        let indexPath = IndexPath(row: 2, section: section)
                                        guard subject.tableView.numberOfRows(inSection: indexPath.section) > indexPath.row else {
                                            fail("No row for \(indexPath)")
                                            return
                                        }
                                        let action = subject.tableView.delegate?.tableView?(subject.tableView, trailingSwipeActionsConfigurationForRowAt: indexPath)?.actions.last

                                        expect(action?.title).to(equal("Mark\nUnread"))
                                        action?.handler(action!, subject.tableView.cellForRow(at: indexPath)!) { completionHandlerCalls.append($0) }
                                    }

                                    it("marks the article as unread with the second action item") {
                                        guard let call = articleCoordinator.markArticleAsReadCalls.last else {
                                            fail("Didn't call ArticleService to mark article as read")
                                            return
                                        }
                                        expect(call.article).to(equal(articles[2]))
                                        expect(call.read).to(beFalse())
                                    }

                                    context("when the articleService successfully marks the article as read") {
                                        var updatedArticle: Article!
                                        beforeEach {
                                            updatedArticle = articleFactory(read: true)
                                            articleCoordinator.markArticleAsReadPublishers.last?.update(with: .success(updatedArticle))
                                        }

                                        it("Updates the articles in the controller to reflect that") {
                                            expect(Array(subject.articles)[2]).to(equal(updatedArticle))
                                        }

                                        it("does not call the completion handler") {
                                            expect(completionHandlerCalls).to(beEmpty())
                                        }

                                        context("if the mark article as read operation updates again with failure") {
                                            beforeEach {
                                                articleCoordinator.markArticleAsReadPublishers.last?.update(with: .failure(.database(.unknown)))
                                            }

                                            itTellsTheUserAboutTheError(title: "Error saving article", message: "Unknown Database Error")

                                            it("does not call the completion handler") {
                                                expect(completionHandlerCalls).to(beEmpty())
                                            }

                                            context("when the mark article as read operation completes") {
                                                beforeEach {
                                                    articleCoordinator.markArticleAsReadPublishers.last?.finish()
                                                }

                                                it("calls the completion handler") {
                                                    expect(completionHandlerCalls).to(equal([false]))
                                                }
                                            }
                                        }

                                        context("when the mark article as read operation completes") {
                                            beforeEach {
                                                articleCoordinator.markArticleAsReadPublishers.last?.finish()
                                            }

                                            it("calls the completion handler") {
                                                expect(completionHandlerCalls).to(equal([true]))
                                            }
                                        }
                                    }

                                    context("when the articleService fails to mark the article as read") {
                                        beforeEach {
                                            articleCoordinator.markArticleAsReadPublishers.last?.update(with: .failure(.database(.unknown)))
                                        }

                                        itTellsTheUserAboutTheError(title: "Error saving article", message: "Unknown Database Error")

                                        it("does not call the completion handler") {
                                            expect(completionHandlerCalls).to(beEmpty())
                                        }

                                        context("if the mark article as read operation updates again with success") {
                                            var updatedArticle: Article!
                                            beforeEach {
                                                updatedArticle = articleFactory()
                                                articleCoordinator.markArticleAsReadPublishers.last?.update(with: .success(updatedArticle))
                                            }

                                            it("Updates the articles in the controller to reflect that") {
                                                expect(subject.articles[AnyIndex(2)]).to(equal(updatedArticle))
                                            }

                                            it("does not call the completion handler") {
                                                expect(completionHandlerCalls).to(beEmpty())
                                            }

                                            context("when the mark article as read operation completes") {
                                                beforeEach {
                                                    articleCoordinator.markArticleAsReadPublishers.last?.finish()
                                                }

                                                it("calls the completion handler") {
                                                    expect(completionHandlerCalls).to(equal([false]))
                                                }
                                            }
                                        }

                                        context("when the mark article as read operation completes") {
                                            beforeEach {
                                                articleCoordinator.markArticleAsReadPublishers.last?.finish()
                                            }

                                            it("calls the completion handler") {
                                                expect(completionHandlerCalls).to(equal([false]))
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        describe("long/force pressing on a cell") {
                            var menuConfiguration: UIContextMenuConfiguration?
                            let indexPath = IndexPath(row: 0, section: section)

                            beforeEach {
                                menuConfiguration = subject.tableView.delegate?.tableView?(subject.tableView, contextMenuConfigurationForRowAt: indexPath, point: .zero)
                            }

                            it("returns a menu configured to show an article") {
                                expect(menuConfiguration).toNot(beNil())
                                let viewController = menuConfiguration?.previewProvider?()
                                expect(viewController).to(beAKindOf(ArticleViewController.self))
                                if let articleController = viewController as? ArticleViewController {
                                    expect(articleController.article).to(equal(articles[0]))
                                }
                            }

                            describe("the menu items") {
                                var menu: UIMenu?

                                beforeEach {
                                    menu = menuConfiguration?.actionProvider?([])
                                }

                                it("has two children, both of which are actions") {
                                    expect(menu?.children).to(haveCount(2))

                                    expect(menu?.children.compactMap { $0 as? UIAction }).to(haveCount(2))
                                }

                                describe("the first action") {
                                    var action: UIAction?
                                    beforeEach {
                                        action = menu?.children.first as? UIAction

                                    }

                                    it("is titled to mark the article as read") {
                                        expect(action?.title).to(equal("Mark Read"))
                                    }

                                    it("uses the mark read image") {
                                        expect(action?.image).to(equal(UIImage(named: "MarkRead")))
                                    }

                                    describe("when selected") {
                                        beforeEach {
                                            action?.handler(action!)
                                        }

                                        it("marks the article as read") {
                                            guard let call = articleCoordinator.markArticleAsReadCalls.last else {
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
                                                articleCoordinator.markArticleAsReadPublishers.last?.update(with: .success(updatedArticle))
                                            }

                                            it("Updates the articles in the controller to reflect that") {
                                                expect(subject.articles.first).to(equal(updatedArticle))
                                            }

                                            it("posts a notification telling other things to reload") {
                                                expect(recorder.notifications).to(haveCount(1))
                                                expect(recorder.notifications.last?.object as? NSObject).to(be(subject))
                                            }

                                            context("if the mark article as read operation updates again with failure") {
                                                beforeEach {
                                                    articleCoordinator.markArticleAsReadPublishers.last?.update(with: .failure(.database(.unknown)))
                                                }

                                                itTellsTheUserAboutTheError(title: "Error saving article", message: "Unknown Database Error")
                                            }
                                        }

                                        context("when the articleService fails to mark the article as read") {
                                            beforeEach {
                                                articleCoordinator.markArticleAsReadPublishers.last?.update(with: .failure(.database(.unknown)))
                                            }

                                            itTellsTheUserAboutTheError(title: "Error saving article", message: "Unknown Database Error")

                                            it("doesn't post a notification") {
                                                expect(recorder.notifications).to(beEmpty())
                                            }

                                            context("if the mark article as read operation updates again with success") {
                                                var updatedArticle: Article!
                                                beforeEach {
                                                    updatedArticle = articleFactory()
                                                    articleCoordinator.markArticleAsReadPublishers.last?.update(with: .success(updatedArticle))
                                                }

                                                it("Updates the articles in the controller to reflect that") {
                                                    expect(subject.articles.first).to(equal(updatedArticle))
                                                }
                                            }
                                        }
                                    }
                                }

                                describe("the second action") {
                                    var action: UIAction?
                                    beforeEach {
                                        action = menu?.children.last as? UIAction
                                    }

                                    it("states that it deletes the article") {
                                        expect(action?.title).to(equal("Delete"))
                                    }

                                    it("shows a trash can icon") {
                                        expect(action?.image).to(equal(UIImage(systemName: "trash")))
                                    }

                                    describe("when selected") {
                                        beforeEach {
                                            action?.handler(action!)
                                        }

                                        it("deletes the article") {
                                            expect(articleCoordinator.removeArticleCalls.last).to(equal(articles.first))
                                        }

                                        xit("shows a spinner while we wait to delete the article") {
                                            fail("Implement me!")
                                        }

                                        context("when the delete operation succeeds") {
                                            beforeEach {
                                                articleCoordinator.removeArticlePromises.last?.resolve(.success(()))
                                            }

                                            it("removes the article from the list") {
                                                expect(Array(subject.articles)).toNot(contain(articles[0]))
                                            }
                                        }

                                        context("when the delete operation fails") {
                                            beforeEach {
                                                articleCoordinator.removeArticlePromises.last?.resolve(.failure(TethysError.database(.unknown)))
                                            }

                                            itTellsTheUserAboutTheError(title: "Error deleting article", message: "Unknown Database Error")

                                            it("keeps the article in the list") {
                                                expect(Array(subject.articles)).to(contain(articles[0]))
                                            }
                                        }
                                    }
                                }
                            }

                            describe("committing the view controller (tapping on it again)") {
                                beforeEach {
                                    guard let config = menuConfiguration else { return }
                                    let animator = FakeContextMenuAnimator(commitStyle: .pop, viewController: menuConfiguration?.previewProvider?())
                                    subject.tableView.delegate?.tableView?(subject.tableView, willPerformPreviewActionForMenuWith: config, animator: animator)

                                    expect(animator.addAnimationsCalls).to(beEmpty())
                                    expect(animator.addCompletionCalls).to(haveCount(1))
                                    animator.addCompletionCalls.last?()
                                }

                                it("navigates to the ArticleViewController") {
                                    expect(navigationController.topViewController).to(beAnInstanceOf(ArticleViewController.self))
                                    if let articleController = navigationController.topViewController as? ArticleViewController {
                                        expect(articleController.article).to(equal(articles[0]))
                                    }
                                }

                                it("marks the article as read") {
                                    expect(articleCoordinator.markArticleAsReadCalls.last?.article).to(equal(articles[0]))
                                }

                                context("if the mark article as read call succeeds") {
                                    var updatedArticle: Article!
                                    beforeEach {
                                        updatedArticle = articleFactory()
                                        articleCoordinator.markArticleAsReadPublishers.last?.update(with: .success(updatedArticle))
                                    }

                                    it("Updates the articles in the controller to reflect that") {
                                        expect(subject.articles.first).to(equal(updatedArticle))
                                    }

                                    it("posts a notification telling other things to reload") {
                                        expect(recorder.notifications).to(haveCount(1))
                                        expect(recorder.notifications.last?.object as? NSObject).to(be(subject))
                                    }

                                    context("if the mark article as read operation updates again with failure") {
                                        beforeEach {
                                            articleCoordinator.markArticleAsReadPublishers.last?.update(with: .failure(.database(.unknown)))
                                        }

                                        itTellsTheUserAboutTheError(title: "Error saving article", message: "Unknown Database Error")
                                    }
                                }

                                context("if the mark article as read call fails") {
                                    beforeEach {
                                        articleCoordinator.markArticleAsReadPublishers.last?.update(with: .failure(.database(.unknown)))
                                    }

                                    itTellsTheUserAboutTheError(title: "Error saving article", message: "Unknown Database Error")

                                    context("if the mark article as read operation updates again with success") {
                                        var updatedArticle: Article!
                                        beforeEach {
                                            updatedArticle = articleFactory()
                                            articleCoordinator.markArticleAsReadPublishers.last?.update(with: .success(updatedArticle))
                                        }

                                        it("Updates the articles in the controller to reflect that") {
                                            expect(subject.articles.first).to(equal(updatedArticle))
                                        }
                                    }
                                }
                            }
                        }

                        describe("when tapped") {
                            beforeEach {
                                let indexPath = IndexPath(row: 0, section: section)
                                guard subject.tableView.numberOfRows(inSection: indexPath.section) > indexPath.row else {
                                    fail("No row for \(indexPath)")
                                    return
                                }
                                subject.tableView(subject.tableView, didSelectRowAt: indexPath)
                            }

                            it("navigates to an ArticleViewController") {
                                expect(navigationController.topViewController).to(beAnInstanceOf(ArticleViewController.self))
                                if let articleController = navigationController.topViewController as? ArticleViewController {
                                    expect(articleController.article).to(equal(articles[0]))
                                }
                            }

                            it("marks the article as read") {
                                expect(articleCoordinator.markArticleAsReadCalls.last?.article).to(equal(articles[0]))
                            }

                            context("if the mark article as read call succeeds") {
                                var updatedArticle: Article!
                                beforeEach {
                                    updatedArticle = articleFactory()
                                    articleCoordinator.markArticleAsReadPublishers.last?.update(with: .success(updatedArticle))
                                }

                                it("Updates the articles in the controller to reflect that") {
                                    expect(subject.articles.first).to(equal(updatedArticle))
                                }

                                it("posts a notification telling other things to reload") {
                                    expect(recorder.notifications).to(haveCount(1))
                                    expect(recorder.notifications.last?.object as? NSObject).to(be(subject))
                                }

                                context("if the mark article as read operation updates again with failure") {
                                    beforeEach {
                                        articleCoordinator.markArticleAsReadPublishers.last?.update(with: .failure(.database(.unknown)))
                                    }

                                    itTellsTheUserAboutTheError(title: "Error saving article", message: "Unknown Database Error")
                                }
                            }

                            context("if the mark article as read call fails") {
                                beforeEach {
                                    articleCoordinator.markArticleAsReadPublishers.last?.update(with: .failure(.database(.unknown)))
                                }

                                itTellsTheUserAboutTheError(title: "Error saving article", message: "Unknown Database Error")

                                it("doesn't post a notification") {
                                    expect(recorder.notifications).to(beEmpty())
                                }

                                context("if the mark article as read operation updates again with success") {
                                    var updatedArticle: Article!
                                    beforeEach {
                                        updatedArticle = articleFactory()
                                        articleCoordinator.markArticleAsReadPublishers.last?.update(with: .success(updatedArticle))
                                    }

                                    it("Updates the articles in the controller to reflect that") {
                                        expect(subject.articles.first).to(equal(updatedArticle))
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
                feedCoordinator.articlesOfFeedPublishers.last?.update(with: .failure(.database(.unknown)))
            }

            itTellsTheUserAboutTheError(title: "Unable to retrieve articles", message: "Unknown Database Error")
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
