import Quick
import Nimble
import Ra
import rNews
import BreakOutToRefresh
import rNewsKit
import Result
import UIKit_PivotalSpecHelperStubs

class FeedsTableViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FeedsTableViewController! = nil
        var dataUseCase: FakeDatabaseUseCase! = nil
        var navigationController: UINavigationController! = nil
        var themeRepository: FakeThemeRepository! = nil
        var settingsRepository: SettingsRepository! = nil
        var analytics: FakeAnalytics! = nil

        var feed1: Feed! = nil

        var feeds: [Feed] = []

        beforeEach {
            let injector = Injector()

            dataUseCase = FakeDatabaseUseCase()
            injector.bind(DatabaseUseCase.self, toInstance: dataUseCase)

            settingsRepository = SettingsRepository(userDefaults: nil)
            injector.bind(SettingsRepository.self, toInstance: settingsRepository)

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, toInstance: themeRepository)

            injector.bind(QuickActionRepository.self, toInstance: FakeQuickActionRepository())
            injector.bind(ImportUseCase.self, toInstance: FakeImportUseCase())
            analytics = FakeAnalytics()
            injector.bind(Analytics.self, toInstance: analytics)

            injector.bind(AccountRepository.self, toInstance: FakeAccountRepository())

            subject = injector.create(FeedsTableViewController)

            navigationController = UINavigationController(rootViewController: subject)

            feed1 = Feed(title: "a", url: NSURL(string: "http://example.com/feed")!, summary: "",
                tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            feeds = [feed1]
        }

        describe("when the view loads") {
            beforeEach {
                expect(subject.view).toNot(beNil())
                subject.viewWillAppear(false)
            }

            it("dismisses the keyboard upon drag") {
                expect(subject.view).toNot(beNil())
                expect(subject.tableView.keyboardDismissMode).to(equal(UIScrollViewKeyboardDismissMode.OnDrag))
            }

            describe("listening to theme repository updates") {
                beforeEach {
                    themeRepository.theme = .Dark
                }

                it("updates the tableView") {
                    expect(subject.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                    expect(subject.tableView.separatorColor).to(equal(themeRepository.textColor))
                }

                it("updates the tableView scroll indicator style") {
                    expect(subject.tableView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
                }

                it("updates the navigation bar background") {
                    expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
                }

                it("updates the searchbar bar style") {
                    expect(subject.searchBar.barStyle).to(equal(themeRepository.barStyle))
                    expect(subject.searchBar.backgroundColor).to(equal(themeRepository.backgroundColor))
                }

                it("updates the drop down menu") {
                    expect(subject.dropDownMenu.buttonBackgroundColor).to(equal(themeRepository.tintColor))
                }

                it("updates the refreshView colors") {
                    expect(subject.refreshView.scenebackgroundColor).to(equal(themeRepository.backgroundColor))
                    expect(subject.refreshView.textColor).to(equal(themeRepository.textColor))
                }
            }


            it("shows an activity indicator") {
                expect(subject.loadingView.superview).toNot(beNil())
                expect(subject.loadingView.message).to(equal("Loading Feeds"))
            }

            it("adds a subscriber to the data use case") {
                expect(dataUseCase.subscribers).toNot(beEmpty())
            }

            describe("responding to data subscriber (feed) update events") {
                var subscriber: DataSubscriber? = nil
                beforeEach {
                    subscriber = dataUseCase.subscribers.anyObject as? DataSubscriber
                }

                context("when the feeds start refreshing") {
                    beforeEach {
                        subscriber?.willUpdateFeeds()
                    }

                    it("should unhide the updateBar") {
                        expect(subject.updateBar.hidden) == false
                    }

                    it("should set the updateBar progress to 0") {
                        expect(subject.updateBar.progress).to(equal(0))
                    }

                    it("should start the pull to refresh") {
                        expect(subject.refreshView.isRefreshing) == true
                    }

                    context("as progress continues") {
                        beforeEach {
                            subscriber?.didUpdateFeedsProgress(1, total: 2)
                        }

                        it("should set the updateBar progress to progress / total") {
                            expect(subject.updateBar.progress).to(equal(0.5))
                        }

                        context("when it finishes") {
                            beforeEach {
                                subscriber?.didUpdateFeeds([])
                            }

                            it("should hide the updateBar") {
                                expect(subject.updateBar.hidden) == true
                            }

                            it("should stop the pull to refresh") {
                                expect(subject.refreshView.isRefreshing) == false
                            }

                            it("should reload the tableView") {
                                expect(dataUseCase.feedsPromises.count) == 2
                            }
                        }
                    }
                }

                context("marking an article as read") {
                    beforeEach {
                        subject.presentViewController(UIViewController(), animated: false, completion: nil)

                        let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])
                        subscriber?.markedArticles([article], asRead: true)
                    }

                    it("refreshes it's feed cache") {
                        expect(dataUseCase.feedsPromises.count) == 2
                    }
                }

                context("deleting an article") {
                    beforeEach {
                        let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])
                        subscriber?.deletedArticle(article)
                    }
                    
                    it("should refresh it's feed cache") {
                        expect(dataUseCase.feedsPromises.count) == 2
                    }
                }
            }

            describe("Key Commands") {
                it("can become first responder") {
                    expect(subject.canBecomeFirstResponder()) == true
                }

                it("have a list of key commands") {
                    let keyCommands = subject.keyCommands
                    expect(keyCommands).toNot(beNil())
                    guard let commands = keyCommands else {
                        return
                    }

                    // cmd+f, cmd+i, cmd+shift+i, cmd+opt+i
                    let expectedCommands = [
                        UIKeyCommand(input: "f", modifierFlags: .Command, action: Selector()),
                        UIKeyCommand(input: "i", modifierFlags: .Command, action: Selector()),
                        UIKeyCommand(input: "i", modifierFlags: [.Command, .Shift], action: Selector()),
                        UIKeyCommand(input: ",", modifierFlags: .Command, action: Selector()),
                        ]
                    let expectedDiscoverabilityTitles = [
                        "Filter by tags",
                        "Add from Web",
                        "Add from Local",
                        "Open settings",
                        ]

                    expect(commands.count).to(equal(expectedCommands.count))
                    for (idx, cmd) in commands.enumerate() {
                        let expectedCmd = expectedCommands[idx]
                        expect(cmd.input).to(equal(expectedCmd.input))
                        expect(cmd.modifierFlags).to(equal(expectedCmd.modifierFlags))

                        let expectedTitle = expectedDiscoverabilityTitles[idx]
                        expect(cmd.discoverabilityTitle).to(equal(expectedTitle))
                    }
                }
            }

            describe("tapping the settings button") {
                beforeEach {
                    subject.navigationItem.leftBarButtonItem?.tap()
                }

                it("should present a settings page") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                    if let nc = subject.presentedViewController as? UINavigationController {
                        expect(nc.topViewController).to(beAnInstanceOf(SettingsViewController.self))
                    }
                }
            }

            describe("tapping the add feed button") {
                var addButton: UIBarButtonItem! = nil
                var buttons: [UIButton] = []
                beforeEach {
                    addButton = subject.navigationItem.rightBarButtonItems?.first
                    addButton.tap()
                    buttons = subject.dropDownMenu.valueForKey("_buttons") as? [UIButton] ?? []
                    expect(buttons).toNot(beEmpty())
                }

                afterEach {
                    navigationController.popToRootViewControllerAnimated(false)
                    subject.dropDownMenu.closeAnimated(false)
                }

                it("should bring up the dropDownMenu") {
                    expect(subject.dropDownMenu.isOpen) == true
                }

                it("should have 2 options") {
                    subject.dropDownMenu.closeAnimated(false)

                    addButton = subject.navigationItem.rightBarButtonItems?.first
                    addButton.tap()
                    buttons = subject.dropDownMenu.valueForKey("_buttons") as? [UIButton] ?? []
                    expect(buttons).toNot(beEmpty())

                    let expectedTitles = ["Add from Web", "Add from Local"]
                    let titles: [String] = buttons.map { $0.titleForState(.Normal) ?? "" }
                    expect(titles).to(equal(expectedTitles))
                }

                context("tapping on the add feed button again") {
                    beforeEach {
                        addButton.tap()
                    }

                    it("should close the dropDownMenu") {
                        expect(subject.dropDownMenu.isOpen) == false
                    }
                }

                context("tapping on add from web") {
                    beforeEach {
                        let button = buttons[0]
                        button.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
                        (subject.presentedViewController as? UINavigationController)?.topViewController?.view
                    }

                    it("should close the dropDownMenu") {
                        expect(subject.dropDownMenu.isOpen) == false
                    }

                    it("should present a FindFeedViewController") {
                        expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                        if let nc = subject.presentedViewController as? UINavigationController {
                            expect(nc.topViewController).to(beAnInstanceOf(FindFeedViewController.self))
                        }
                    }
                }

                context("tapping on add from local") {
                    beforeEach {
                        let button = buttons[1]
                        button.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
                    }

                    it("should close the dropDownMenu") {
                        expect(subject.dropDownMenu.isOpen) == false
                    }

                    it("should present a LocalImportViewController") {
                        expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                        if let nc = subject.presentedViewController as? UINavigationController {
                            expect(nc.topViewController).to(beAnInstanceOf(LocalImportViewController.self))
                        }
                    }
                }
            }

            it("it makes a request to the data use case for feeds") {
                expect(dataUseCase.feedsPromises.count) == 1
            }

            describe("when the feeds promise succeeds") {
                context("with a set of feeds") {
                    beforeEach {
                        feeds = [feed1]
                        dataUseCase.feedsPromises.first?.resolve(.Success(feeds))
                    }

                    it("does not show the onboarding view") {
                        expect(subject.onboardingView.superview).to(beNil())
                    }

                    describe("typing in the searchbar") {
                        describe("entering a query that has feeds matching that tag") {
                            beforeEach {
                                subject.searchBar.delegate?.searchBar?(subject.searchBar, textDidChange: "a")
                            }

                            it("makes another request for the feeds") {
                                expect(dataUseCase.feedsPromises.count) == 2
                            }

                            context("when the feeds come back") {
                                beforeEach {
                                    dataUseCase.feedsPromises.last?.resolve(.Success(feeds))
                                }

                                it("should filter feeds down to only those with tags that match the search string") {
                                    expect(subject.tableView.numberOfRowsInSection(0)) == 1

                                    if let cell = subject.tableView.visibleCells.first as? FeedTableCell {
                                        expect(cell.feed) == feeds[0]
                                    }
                                }
                            }
                        }

                        describe("filtering down to no feeds") {
                            beforeEach {
                                subject.searchBar.delegate?.searchBar?(subject.searchBar, textDidChange: "aoeu")
                            }

                            it("makes another request for the feeds") {
                                expect(dataUseCase.feedsPromises.count) == 2
                            }

                            context("when the feeds come back") {
                                beforeEach {
                                    dataUseCase.feedsPromises.last?.resolve(.Success(feeds))
                                }

                                it("should not show the onboarding view") {
                                    expect(subject.onboardingView.superview).to(beNil())
                                }
                            }
                        }
                    }

                    describe("pull to refresh") {
                        beforeEach {
                            expect(dataUseCase.didUpdateFeeds) == false
                            subject.refreshView.beginRefreshing()
                            subject.refreshViewDidRefresh(subject.refreshView)
                        }

                        it("should tell the dataManager to updateFeeds") {
                            expect(dataUseCase.didUpdateFeeds) == true
                        }

                        it("should be refreshing") {
                            expect(subject.refreshView.isRefreshing) == true
                        }

                        context("when the call succeeds") {
                            var feed3: Feed! = nil
                            beforeEach {
                                feed3 = Feed(title: "d", url: NSURL(string: "https://example.com")!, summary: "", tags: [],
                                    waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                                dataUseCase.updateFeedsCompletion([], [])
                                for object in dataUseCase.subscribers.allObjects {
                                    if let subscriber = object as? DataSubscriber {
                                        subscriber.didUpdateFeeds([])
                                    }
                                }
                            }

                            it("stops refreshing") {
                                expect(subject.refreshView.isRefreshing) == false
                            }

                            it("makes another request for the feeds") {
                                expect(dataUseCase.feedsPromises.count) == 2
                            }

                            it("reloads the tableView when the promise returns") {
                                dataUseCase.feedsPromises.last?.resolve(.Success(feeds + [feed3]))
                                expect(subject.tableView.numberOfRowsInSection(0)) == 2 // cause it was 1
                            }
                        }

                        context("when the call fails") {
                            beforeEach {
                                let error = NSError(domain: "NSURLErrorDomain", code: -1001, userInfo: [NSLocalizedFailureReasonErrorKey: "The request timed out.", "feedTitle": "foo"])
                                UIView.pauseAnimations()
                                dataUseCase.updateFeedsCompletion([], [error])
                            }

                            afterEach {
                                UIView.resetAnimations()
                            }

                            it("should end refreshing") {
                                for object in dataUseCase.subscribers.allObjects {
                                    if let subscriber = object as? DataSubscriber {
                                        subscriber.didUpdateFeeds([])
                                    }
                                }
                                expect(subject.refreshView.isRefreshing) == false
                            }
                            
                            it("should bring up an alert notifying the user") {
                                expect(subject.notificationView.titleLabel.hidden) == false
                                expect(subject.notificationView.titleLabel.text).to(equal("Unable to update feeds"))
                                expect(subject.notificationView.messageLabel.text).to(equal("foo: The request timed out."))
                            }
                        }
                    }

                    describe("the tableView") {
                        it("should have a row for each feed") {
                            expect(subject.tableView.numberOfRowsInSection(0)) == feeds.count
                        }

                        describe("a cell") {
                            var cell: FeedTableCell? = nil
                            var feed: Feed! = nil

                            context("for a regular feed") {
                                beforeEach {
                                    cell = subject.tableView.visibleCells.first as? FeedTableCell
                                    feed = feeds[0]

                                    expect(cell).to(beAnInstanceOf(FeedTableCell.self))
                                }

                                it("should be configured with the theme repository") {
                                    expect(cell?.themeRepository).to(beIdenticalTo(themeRepository))
                                }

                                it("should be configured with the feed") {
                                    expect(cell?.feed).to(equal(feed))
                                }

                                describe("tapping on a cell") {
                                    beforeEach {
                                        let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                                        if let _ = cell {
                                            subject.tableView(subject.tableView, didSelectRowAtIndexPath: indexPath)
                                        }
                                    }

                                    it("should navigate to an ArticleListViewController for that feed") {
                                        expect(navigationController.topViewController).to(beAnInstanceOf(ArticleListController.self))
                                        if let articleList = navigationController.topViewController as? ArticleListController {
                                            expect(articleList.feed) == feed
                                        }
                                    }
                                }

                                describe("force pressing a cell") {
                                    var viewControllerPreviewing: FakeUIViewControllerPreviewing! = nil
                                    var viewController: UIViewController? = nil

                                    beforeEach {
                                        viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRectZero, delegate: subject)

                                        let rect = subject.tableView.rectForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0))
                                        let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                                        viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                                    }

                                    it("should return an ArticleListController configured with the feed's articles to present to the user") {
                                        expect(viewController).to(beAKindOf(ArticleListController.self))
                                        if let articleVC = viewController as? ArticleListController {
                                            expect(articleVC.feed) == feed
                                        }
                                    }

                                    it("should push the view controller when commited") {
                                        if let vc = viewController {
                                            subject.previewingContext(viewControllerPreviewing, commitViewController: vc)
                                            expect(navigationController.topViewController) === viewController
                                        }
                                    }
                                }

                                describe("exposing edit actions") {
                                    var actions: [UITableViewRowAction] = []
                                    var action: UITableViewRowAction? = nil
                                    let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                                    beforeEach {
                                        action = nil
                                        if let _ = cell {
                                            actions = subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath) ?? []
                                        }
                                    }

                                    it("should have 4 actions") {
                                        expect(actions.count).to(equal(4))
                                    }

                                    describe("the first action") {
                                        beforeEach {
                                            action = actions.first
                                        }

                                        it("should state it deletes the feed") {
                                            expect(action?.title).to(equal("Delete"))
                                        }

                                        describe("tapping it") {
                                            beforeEach {
                                                action?.handler(action, indexPath)
                                            }

                                            it("does not yet delete the feed from the data store") {
                                                expect(dataUseCase.lastDeletedFeed).to(beNil())
                                            }

                                            it("presents an alert asking for confirmation that the user wants to do this") {
                                                expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                                guard let alert = subject.presentedViewController as? UIAlertController else { return }
                                                expect(alert.preferredStyle) == UIAlertControllerStyle.Alert
                                                expect(alert.title) == "Delete \(feed.displayTitle)?"

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

                                                it("deletes the feed from the data store") {
                                                    expect(dataUseCase.lastDeletedFeed) == feed
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

                                                it("does not delete the feed from the data store") {
                                                    expect(dataUseCase.lastDeletedFeed).to(beNil())
                                                }

                                                it("dismisses the alert") {
                                                    expect(subject.presentedViewController).to(beNil())
                                                }
                                            }
                                        }
                                    }

                                    describe("the second action") {
                                        beforeEach {
                                            if actions.count > 1 {
                                                action = actions[1]
                                            }
                                        }

                                        it("should state it marks all items in the feed as read") {
                                            expect(action?.title).to(equal("Mark\nRead"))
                                        }

                                        describe("tapping it") {
                                            beforeEach {
                                                action?.handler(action, indexPath)
                                            }

                                            it("marks all articles of that feed as read") {
                                                expect(dataUseCase.lastFeedMarkedRead).to(equal(feed))
                                            }

                                            it("when the subscriber gets a marked articles notice it does not refresh it's feed cache") {
                                                let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])
                                                dataUseCase.subscribersArray.first?.markedArticles([article], asRead: true)
                                                expect(dataUseCase.feedsPromises.count) == 1
                                            }

                                            it("causes a refresh of the feeds") {
                                                dataUseCase.lastFeedMarkedReadPromise?.resolve(.Success(0))
                                                expect(dataUseCase.feedsPromises.count) == 2
                                            }
                                        }
                                    }

                                    describe("the third action") {
                                        beforeEach {
                                            if actions.count > 2 {
                                                action = actions[2]
                                            }
                                        }

                                        it("should state it edits the feed") {
                                            expect(action?.title).to(equal("Edit"))
                                        }

                                        describe("tapping it") {
                                            beforeEach {
                                                action?.handler(action, indexPath)
                                            }

                                            it("should bring up a feed edit screen") {
                                                expect(navigationController.visibleViewController).to(beAnInstanceOf(UINavigationController.self))
                                                if let nc = navigationController.visibleViewController as? UINavigationController {
                                                    expect(nc.viewControllers.count).to(equal(1))
                                                    expect(nc.topViewController).to(beAnInstanceOf(FeedViewController.self))
                                                }
                                            }
                                        }
                                    }

                                    describe("the fourth action") {
                                        beforeEach {
                                            if actions.count > 3 {
                                                action = actions[3]
                                            }
                                        }

                                        it("should state it opens a share sheet") {
                                            expect(action?.title).to(equal("Share"))
                                        }

                                        describe("tapping it") {
                                            beforeEach {
                                                action?.handler(action, indexPath)
                                            }

                                            it("should bring up a share sheet") {
                                                expect(navigationController.visibleViewController).to(beAnInstanceOf(UIActivityViewController))
                                                if let activityVC = navigationController.visibleViewController as? UIActivityViewController {
                                                    expect(activityVC.activityItems as? [NSURL]) == [feed.url]
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                context("but no feeds were found") {
                    beforeEach {
                        dataUseCase.feedsPromises.first?.resolve(.Success([]))
                    }

                    it("hides the activity indicator") {
                        expect(subject.loadingView.superview).to(beNil())
                    }

                    it("shows the onboarding view") {
                        expect(subject.onboardingView.superview).toNot(beNil())
                    }
                }
            }

            xdescribe("when the feeds promise fails") { // TODO: Implement!
                beforeEach {
                    UIView.pauseAnimations()
                    dataUseCase.feedsPromises.first?.resolve(.Failure(.Unknown))
                }

                afterEach {
                    UIView.resetAnimations()
                }

                it("hides the activity indicator") {
                    expect(subject.loadingView.superview).to(beNil())
                }

                it("does not show the onboarding view") {
                    expect(subject.onboardingView.superview).to(beNil())
                }

                it("brings up an alert notifying the user") {
                    expect(subject.notificationView.titleLabel.hidden) == false
                    expect(subject.notificationView.titleLabel.text) == "Error"
                    expect(subject.notificationView.messageLabel.text) == "Unknown Error"
                }
            }
        }
    }
}
