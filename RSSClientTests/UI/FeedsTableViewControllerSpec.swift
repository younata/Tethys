import Quick
import Nimble
import Ra
import rNews
import BreakOutToRefresh
import rNewsKit
import UIKit_PivotalSpecHelperStubs

class FeedsTableViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FeedsTableViewController! = nil
        var dataRepository: FakeFeedRepository! = nil
        var navigationController: UINavigationController! = nil
        var themeRepository: FakeThemeRepository! = nil
        var settingsRepository: SettingsRepository! = nil

        var feed1: Feed! = nil
        var feed2: Feed! = nil

        var feeds: [Feed] = []

        beforeEach {
            let injector = Injector()

            SpecInjectorModule().configureInjector(injector)

            dataRepository = FakeFeedRepository()
            injector.bind(FeedRepository.self, toInstance: dataRepository)

            settingsRepository = SettingsRepository(userDefaults: nil)
            injector.bind(SettingsRepository.self, toInstance: settingsRepository)

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, toInstance: themeRepository)

            subject = injector.create(FeedsTableViewController)

            navigationController = UINavigationController(rootViewController: subject)

            feed1 = Feed(title: "a", url: NSURL(string: "http://example.com/feed"), summary: "", query: nil,
                tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            feed2 = Feed(title: "d", url: nil, summary: "", query: "article.read == false;", tags: [],
                waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            feeds = [feed1, feed2]

            dataRepository.feedsList = feeds
        }

        it("dismisses the keyboard upon drag") {
            expect(subject.view).toNot(beNil())
            expect(subject.tableView.keyboardDismissMode).to(equal(UIScrollViewKeyboardDismissMode.OnDrag))
        }

        describe("listening to theme repository updates") {
            beforeEach {
                expect(subject.view).toNot(beNil())
                subject.viewWillAppear(false)

                themeRepository.theme = .Dark
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

            it("should update the searchbar bar style") {
                expect(subject.searchBar.barStyle).to(equal(themeRepository.barStyle))
                expect(subject.searchBar.backgroundColor).to(equal(themeRepository.backgroundColor))
            }

            it("should update the drop down menu") {
                expect(subject.dropDownMenu.buttonBackgroundColor).to(equal(themeRepository.tintColor))
            }

            it("should update the refreshView colors") {
                expect(subject.refreshView.scenebackgroundColor).to(equal(themeRepository.backgroundColor))
                expect(subject.refreshView.textColor).to(equal(themeRepository.textColor))
            }
        }

        context("before feed results come back") {
            beforeEach {
                dataRepository.feedsList = nil

                expect(subject.view).toNot(beNil())
                subject.viewWillAppear(false)
            }

            it("should show an activity indicator") {
                expect(subject.loadingView.superview).toNot(beNil())
            }

            it("should have the correct message for the activity indicator") {
                expect(subject.loadingView.message).to(equal("Loading Feeds"))
            }

            describe("when the feed results come back") {
                beforeEach {
                    dataRepository.feedsCallback?([])
                }

                it("should hide the activity indicator") {
                    expect(subject.loadingView.superview).to(beNil())
                }
            }
        }

        context("when there are no feeds to display") {
            beforeEach {
                feeds = []

                dataRepository.feedsList = feeds

                expect(subject.view).toNot(beNil())
                subject.viewWillAppear(false)
            }

            it("should show the onboarding view") {
                expect(subject.onboardingView.superview).toNot(beNil())
            }

            context("when feeds are added") {
                beforeEach {
                    feeds = [feed1, feed2]

                    dataRepository.feedsList = feeds
                    subject.searchBar.delegate?.searchBar?(subject.searchBar, textDidChange: "") // just to trigger a reload
                }

                it("should not show the onboarding view") {
                    expect(subject.onboardingView.superview).to(beNil())
                }
            }
        }

        context("when there is just the All Unread feed to display") {
            beforeEach {
                feeds = [
                    Feed(title: "All Unread", url: nil, summary: "All unread articles", query: "function(article) {\n    return !article.read;\n}", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                ]

                dataRepository.feedsList = feeds

                expect(subject.view).toNot(beNil())
                subject.viewWillAppear(false)
            }

            it("should show the onboarding view") {
                expect(subject.onboardingView.superview).toNot(beNil())
            }

            context("when feeds are added") {
                beforeEach {
                    feeds = [feed1, feed2]

                    dataRepository.feedsList = feeds
                    subject.searchBar.delegate?.searchBar?(subject.searchBar, textDidChange: "") // just to trigger a reload
                }

                it("should not show the onboarding view") {
                    expect(subject.onboardingView.superview).to(beNil())
                }
            }
        }

        context("when there are feeds to display") {
            beforeEach {
                feeds = [feed1, feed2]

                dataRepository.feedsList = feeds

                expect(subject.view).toNot(beNil())
                subject.viewWillAppear(false)
            }

            it("should not show the onboarding view") {
                expect(subject.onboardingView.superview).to(beNil())
            }

            it("should add a subscriber to the dataWriter") {
                expect(dataRepository.subscribers).toNot(beEmpty())
            }

            describe("responding to data subscriber (feed) update events") {
                var subscriber: DataSubscriber? = nil
                beforeEach {
                    subscriber = dataRepository.subscribers.anyObject as? DataSubscriber
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
                                expect(dataRepository.didAskForFeeds) == true
                            }
                        }
                    }
                }

                context("marking an article as read") {
                    beforeEach {
                        dataRepository.didAskForFeeds = false
                        let article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
                        subscriber?.markedArticles([article], asRead: true)
                    }

                    it("should refresh it's feed cache") {
                        expect(dataRepository.didAskForFeeds) == true
                    }
                }

                context("deleting an article") {
                    beforeEach {
                        dataRepository.didAskForFeeds = false
                        let article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
                        subscriber?.deletedArticle(article)
                    }

                    it("should refresh it's feed cache") {
                        expect(dataRepository.didAskForFeeds) == true
                    }
                }
            }

            describe("Key Commands") {
                it("can become first responder") {
                    expect(subject.canBecomeFirstResponder()) == true
                }

                context("when query feeds are enabled") {
                    beforeEach {
                        settingsRepository.queryFeedsEnabled = true
                    }

                    it("have a list of key commands") {
                        let keyCommands = subject.keyCommands
                        expect(keyCommands).toNot(beNil())
                        guard let commands = keyCommands else {
                            return
                        }

                        // cmd+f, cmd+i, cmd+shift+i, cmd+opt+i
                        let expectedCommands = [
                            UIKeyCommand(input: "f", modifierFlags: .Command, action: ""),
                            UIKeyCommand(input: "i", modifierFlags: .Command, action: ""),
                            UIKeyCommand(input: "i", modifierFlags: [.Command, .Shift], action: ""),
                            UIKeyCommand(input: "i", modifierFlags: [.Command, .Alternate], action: ""),
                            UIKeyCommand(input: ",", modifierFlags: .Command, action: ""),
                        ]
                        let expectedDiscoverabilityTitles = [
                            "Filter by tags",
                            "Add from Web",
                            "Add from Local",
                            "Create Query Feed",
                            "Open settings",
                        ]

                        expect(commands.count).to(equal(expectedCommands.count))
                        for (idx, cmd) in commands.enumerate() {
                            let expectedCmd = expectedCommands[idx]
                            expect(cmd.input).to(equal(expectedCmd.input))
                            expect(cmd.modifierFlags).to(equal(expectedCmd.modifierFlags))

                            if #available(iOS 9.0, *) {
                                let expectedTitle = expectedDiscoverabilityTitles[idx]
                                expect(cmd.discoverabilityTitle).to(equal(expectedTitle))
                            }
                        }
                    }
                }

                context("when query feeds are disabled") {
                    beforeEach {
                        settingsRepository.queryFeedsEnabled = false
                    }

                    it("have a list of key commands") {
                        let keyCommands = subject.keyCommands
                        expect(keyCommands).toNot(beNil())
                        guard let commands = keyCommands else {
                            return
                        }

                        // cmd+f, cmd+i, cmd+shift+i, cmd+opt+i
                        let expectedCommands = [
                            UIKeyCommand(input: "f", modifierFlags: .Command, action: ""),
                            UIKeyCommand(input: "i", modifierFlags: .Command, action: ""),
                            UIKeyCommand(input: "i", modifierFlags: [.Command, .Shift], action: ""),
                            UIKeyCommand(input: ",", modifierFlags: .Command, action: ""),
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

                            if #available(iOS 9.0, *) {
                                let expectedTitle = expectedDiscoverabilityTitles[idx]
                                expect(cmd.discoverabilityTitle).to(equal(expectedTitle))
                            }
                        }
                    }
                }
            }

            describe("typing in the searchbar") {
                beforeEach {
                    subject.searchBar.delegate?.searchBar?(subject.searchBar, textDidChange: "a")
                }

                it("should filter feeds down to only those with tags that match the search string") {
                    expect(subject.tableView.numberOfRowsInSection(0)).to(equal(1))

                    if let cell = subject.tableView.visibleCells[0] as? FeedTableCell {
                        expect(cell.feed).to(equal(feeds[0]))
                    }
                }

                describe("filtering down to no feeds") {
                    beforeEach {
                        subject.searchBar.delegate?.searchBar?(subject.searchBar, textDidChange: "aoeu")
                    }

                    it("should not show the onboarding view") {
                        expect(subject.onboardingView.superview).to(beNil())
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

                context("when query feeds are available") {
                    beforeEach {
                        settingsRepository.queryFeedsEnabled = true
                    }

                    it("should have 3 options") {
                        subject.dropDownMenu.closeAnimated(false)

                        addButton = subject.navigationItem.rightBarButtonItems?.first
                        addButton.tap()
                        buttons = subject.dropDownMenu.valueForKey("_buttons") as? [UIButton] ?? []
                        expect(buttons).toNot(beEmpty())

                        let expectedTitles = ["Add from Web", "Add from Local", "Create Query Feed"]
                        let titles: [String] = buttons.map { $0.titleForState(.Normal) ?? "" }
                        expect(titles).to(equal(expectedTitles))
                    }
                }

                context("when query feeds are not available") {
                    beforeEach {
                        settingsRepository.queryFeedsEnabled = false
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

                context("tapping on create query feed") {
                    beforeEach {
                        subject.dropDownMenu.closeAnimated(false)

                        settingsRepository.queryFeedsEnabled = true
                        addButton = subject.navigationItem.rightBarButtonItems?.first
                        addButton.tap()
                        buttons = subject.dropDownMenu.valueForKey("_buttons") as? [UIButton] ?? []
                        expect(buttons.count).to(beGreaterThan(2))

                        let button = buttons[2]
                        button.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
                    }

                    it("should close the dropDownMenu") {
                        expect(subject.dropDownMenu.isOpen) == false
                    }

                    it("should present a QueryFeedViewController") {
                        expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                        if let nc = subject.presentedViewController as? UINavigationController {
                            expect(nc.topViewController).to(beAnInstanceOf(QueryFeedViewController.self))
                        }
                    }
                }
            }

            describe("pull to refresh") {
                beforeEach {
                    expect(dataRepository.didUpdateFeeds) == false
                    subject.refreshView.beginRefreshing()
                    subject.refreshViewDidRefresh(subject.refreshView)
                }

                it("should tell the dataManager to updateFeeds") {
                    expect(dataRepository.didUpdateFeeds) == true
                }

                it("should be refreshing") {
                    expect(subject.refreshView.isRefreshing) == true
                }

                context("when the call succeeds") {
                    var feed3: Feed! = nil
                    beforeEach {
                        feed3 = Feed(title: "d", url: nil, summary: "", query: "", tags: [],
                            waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                        dataRepository.feedsList = feeds + [feed3]
                        dataRepository.updateFeedsCompletion([], [])
                        for object in dataRepository.subscribers.allObjects {
                            if let subscriber = object as? DataSubscriber {
                                subscriber.didUpdateFeeds([])
                            }
                        }
                    }

                    it("should end refreshing") {
                        expect(subject.refreshView.isRefreshing) == false
                    }

                    it("should reload the tableView") {
                        expect(subject.tableView.numberOfRowsInSection(0)).to(equal(3)) // cause it was 2
                    }
                }

                context("when the call fails") {
                    beforeEach {
                        let error = NSError(domain: "NSURLErrorDomain", code: -1001, userInfo: [NSLocalizedFailureReasonErrorKey: "The request timed out.", "feedTitle": "foo"])
                        UIView.pauseAnimations()
                        dataRepository.updateFeedsCompletion([], [error])
                    }

                    afterEach {
                        UIView.resetAnimations()
                    }

                    it("should end refreshing") {
                        for object in dataRepository.subscribers.allObjects {
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
                    expect(subject.tableView.numberOfRowsInSection(0)).to(equal(feeds.count))
                }

                describe("a cell") {
                    var cell: FeedTableCell! = nil
                    var feed: Feed! = nil

                    context("for a regular feed") {
                        beforeEach {
                            cell = subject.tableView.visibleCells.first as? FeedTableCell
                            feed = feeds[0]

                            expect(cell).to(beAnInstanceOf(FeedTableCell.self))
                        }

                        it("should be configured with the theme repository") {
                            expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                        }

                        it("should be configured with the feed") {
                            expect(cell.feed).to(equal(feed))
                        }

                        describe("tapping on a cell") {
                            beforeEach {
                                let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                                subject.tableView(subject.tableView, didSelectRowAtIndexPath: indexPath)
                            }

                            it("should navigate to an ArticleListViewController for that feed") {
                                expect(navigationController.topViewController).to(beAnInstanceOf(ArticleListController.self))
                                if let articleList = navigationController.topViewController as? ArticleListController {
                                    expect(articleList.feeds == [feed]) == true
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
                                    expect(articleVC.feeds == [feed]) == true
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
                            var action: UITableViewRowAction! = nil
                            let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                            beforeEach {
                                actions = subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath) ?? []
                            }

                            it("should have 3 actions") {
                                expect(actions.count).to(equal(3))
                            }

                            describe("the first action") {
                                beforeEach {
                                    action = actions[0]
                                }

                                it("should state it deletes the feed") {
                                    expect(action.title).to(equal("Delete"))
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action.handler()(action, indexPath)
                                    }

                                    it("should delete the feed from the data store") {
                                        expect(dataRepository.lastDeletedFeed).to(equal(feed))
                                    }
                                }
                            }

                            describe("the second action") {
                                beforeEach {
                                    action = actions[1]
                                }

                                it("should state it marks all items in the feed as read") {
                                    expect(action.title).to(equal("Mark\nRead"))
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action.handler()(action, indexPath)
                                    }

                                    it("should mark all articles of that feed as read") {
                                        expect(dataRepository.lastFeedMarkedRead).to(equal(feed))
                                    }
                                }
                            }

                            describe("the third action") {
                                beforeEach {
                                    action = actions[2]
                                }

                                it("should state it edits the feed") {
                                    expect(action.title).to(equal("Edit"))
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action.handler()(action, indexPath)
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
                        }
                    }

                    context("for a query feed") {
                        beforeEach {
                            cell = subject.tableView.visibleCells.last as? FeedTableCell
                            feed = feeds[1]

                            expect(cell).to(beAnInstanceOf(FeedTableCell.self))
                        }

                        it("should be configured with the theme repository") {
                            expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                        }

                        it("should be configured with the feed") {
                            expect(cell.feed).to(equal(feed))
                        }

                        describe("tapping on a cell") {
                            beforeEach {
                                let indexPath = NSIndexPath(forRow: 1, inSection: 0)
                                subject.tableView(subject.tableView, didSelectRowAtIndexPath: indexPath)
                            }

                            it("should navigate to an ArticleListViewController for that feed") {
                                expect(navigationController.topViewController).to(beAnInstanceOf(ArticleListController.self))
                                if let articleList = navigationController.topViewController as? ArticleListController {
                                    expect(articleList.feeds == [feed]) == true
                                }
                            }
                        }

                        describe("force pressing a cell") {
                            var viewControllerPreviewing: FakeUIViewControllerPreviewing! = nil
                            var viewController: UIViewController? = nil

                            beforeEach {
                                viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRectZero, delegate: subject)

                                let rect = subject.tableView.rectForRowAtIndexPath(NSIndexPath(forRow: 1, inSection: 0))
                                let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                                viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                            }

                            it("should return an ArticleListController configured with the feed's articles to present to the user") {
                                expect(viewController).to(beAKindOf(ArticleListController.self))
                                if let articleVC = viewController as? ArticleListController {
                                    expect(articleVC.feeds == [feed]) == true
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
                            var action: UITableViewRowAction! = nil
                            let indexPath = NSIndexPath(forRow: 1, inSection: 0)
                            beforeEach {
                                actions = subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath) ?? []
                            }

                            it("should have 3 actions") {
                                expect(actions.count).to(equal(3))
                            }

                            describe("the first action") {
                                beforeEach {
                                    action = actions[0]
                                }

                                it("should state it deletes the feed") {
                                    expect(action.title).to(equal("Delete"))
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action.handler()(action, indexPath)
                                    }

                                    it("should delete the feed from the data store") {
                                        expect(dataRepository.lastDeletedFeed).to(equal(feed))
                                    }
                                }
                            }

                            describe("the second action") {
                                beforeEach {
                                    action = actions[1]
                                }

                                it("should state it marks all items in the feed as read") {
                                    expect(action.title).to(equal("Mark\nRead"))
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action.handler()(action, indexPath)
                                    }

                                    it("should mark all articles of that feed as read") {
                                        expect(dataRepository.lastFeedMarkedRead).to(equal(feed))
                                    }
                                }
                            }

                            describe("the second action") {
                                beforeEach {
                                    action = actions[2]
                                }

                                it("should state it edits the feed") {
                                    expect(action.title).to(equal("Edit"))
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action.handler()(action, indexPath)
                                    }

                                    it("should bring up a feed edit screen") {
                                        expect(navigationController.visibleViewController).to(beAnInstanceOf(UINavigationController.self))
                                        if let nc = navigationController.visibleViewController as? UINavigationController {
                                            expect(nc.viewControllers.count).to(equal(1))
                                            expect(nc.topViewController).to(beAnInstanceOf(QueryFeedViewController.self))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
