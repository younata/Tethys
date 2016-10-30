import Quick
import Nimble
import Ra
import rNews
import BreakOutToRefresh
import rNewsKit
import Result
import UIKit_PivotalSpecHelperStubs
import CBGPromise

class FeedsTableViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FeedsTableViewController! = nil
        var dataUseCase: FakeDatabaseUseCase! = nil
        var navigationController: UINavigationController! = nil
        var themeRepository: ThemeRepository! = nil
        var settingsRepository: SettingsRepository! = nil
        var analytics: FakeAnalytics! = nil
        var mainQueue: FakeOperationQueue!

        var feed1: Feed! = nil

        var feeds: [Feed] = []

        beforeEach {
            let injector = Injector()

            dataUseCase = FakeDatabaseUseCase()
            injector.bind(kind: DatabaseUseCase.self, toInstance: dataUseCase)

            injector.bind(kind: OPMLService.self, toInstance: FakeOPMLService())

            mainQueue = FakeOperationQueue()
            injector.bind(string: kMainQueue, toInstance: mainQueue)

            settingsRepository = SettingsRepository(userDefaults: nil)
            injector.bind(kind: SettingsRepository.self, toInstance: settingsRepository)

            themeRepository = ThemeRepository(userDefaults: nil)
            injector.bind(kind: ThemeRepository.self, toInstance: themeRepository)

            injector.bind(kind: QuickActionRepository.self, toInstance: FakeQuickActionRepository())
            injector.bind(kind: ImportUseCase.self, toInstance: FakeImportUseCase())
            analytics = FakeAnalytics()
            injector.bind(kind: Analytics.self, toInstance: analytics)

            injector.bind(kind: AccountRepository.self, toInstance: FakeAccountRepository())

            subject = injector.create(kind: FeedsTableViewController.self)

            navigationController = UINavigationController(rootViewController: subject)

            feed1 = Feed(title: "a", url: URL(string: "http://example.com/feed")!, summary: "",
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
                expect(subject.tableView.keyboardDismissMode).to(equal(UIScrollViewKeyboardDismissMode.onDrag))
            }

            describe("listening to theme repository updates") {
                beforeEach {
                    themeRepository.theme = .dark
                }

                it("updates the tableView") {
                    expect(subject.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                    expect(subject.tableView.separatorColor).to(equal(themeRepository.textColor))
                }

                it("updates the tableView scroll indicator style") {
                    expect(subject.tableView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
                }

                it("updates the navigation bar") {
                    expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
                    expect(subject.navigationController?.navigationBar.titleTextAttributes as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
                }

                it("updates the searchbar bar style") {
                    expect(subject.searchBar.barStyle).to(equal(themeRepository.barStyle))
                    expect(subject.searchBar.backgroundColor).to(equal(themeRepository.backgroundColor))
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
                        expect(subject.updateBar.isHidden) == false
                    }

                    it("should set the updateBar progress to 0") {
                        expect(subject.updateBar.progress).to(equal(0))
                    }

                    it("should start the pull to refresh") {
                        expect(subject.refreshControl.isRefreshing) == true
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
                                expect(subject.updateBar.isHidden) == true
                            }

                            it("should stop the pull to refresh") {
                                expect(subject.refreshControl.isRefreshing) == false
                            }

                            it("should reload the tableView") {
                                expect(dataUseCase.feedsPromises.count) == 2
                            }
                        }
                    }
                }

                context("marking an article as read") {
                    beforeEach {
                        subject.present(UIViewController(), animated: false, completion: nil)

                        let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])
                        subscriber?.markedArticles([article], asRead: true)
                    }

                    it("refreshes it's feed cache") {
                        expect(dataUseCase.feedsPromises.count) == 2
                    }
                }

                context("deleting an article") {
                    beforeEach {
                        let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])
                        subscriber?.deletedArticle(article)
                    }
                    
                    it("should refresh it's feed cache") {
                        expect(dataUseCase.feedsPromises.count) == 2
                    }
                }
            }

            describe("Key Commands") {
                it("can become first responder") {
                    expect(subject.canBecomeFirstResponder) == true
                }

                it("have a list of key commands") {
                    let keyCommands = subject.keyCommands
                    expect(keyCommands).toNot(beNil())
                    guard let commands = keyCommands else {
                        return
                    }

                    // cmd+f, cmd+i, cmd+shift+i, cmd+opt+i
                    let expectedCommands = [
                        UIKeyCommand(input: "f", modifierFlags: .command, action: Selector("")),
                        UIKeyCommand(input: "i", modifierFlags: .command, action: Selector("")),
                        UIKeyCommand(input: ",", modifierFlags: .command, action: Selector("")),
                        ]
                    let expectedDiscoverabilityTitles = [
                        "Filter by tags",
                        "Add from Web",
                        "Open settings",
                        ]

                    expect(commands.count).to(equal(expectedCommands.count))
                    for (idx, cmd) in commands.enumerated() {
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
                beforeEach {
                    subject.navigationItem.rightBarButtonItems?.first?.tap()
                }

                afterEach {
                    navigationController.popToRootViewController(animated: false)
                }

                it("should present a FindFeedViewController") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                    if let nc = subject.presentedViewController as? UINavigationController {
                        expect(nc.topViewController).to(beAnInstanceOf(FindFeedViewController.self))
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
                        dataUseCase.feedsPromises.first?.resolve(.success(feeds))
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
                                    dataUseCase.feedsPromises.last?.resolve(.success(feeds))
                                }

                                it("should filter feeds down to only those with tags that match the search string") {
                                    expect(subject.tableView.numberOfRows(inSection: 0)) == 1

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
                                    dataUseCase.feedsPromises.last?.resolve(.success(feeds))
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
                            subject.refreshControl.beginRefreshing()
                            subject.refreshControl.refreshViewDidRefresh(subject.refreshControl.breakoutView)
                        }

                        it("should tell the dataManager to updateFeeds") {
                            expect(dataUseCase.didUpdateFeeds) == true
                        }

                        it("should be refreshing") {
                            expect(subject.refreshControl.isRefreshing) == true
                        }

                        context("when the call succeeds") {
                            var feed3: Feed! = nil
                            beforeEach {
                                feed3 = Feed(title: "d", url: URL(string: "https://example.com")!, summary: "", tags: [],
                                    waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                                dataUseCase.updateFeedsCompletion([], [])
                                for object in dataUseCase.subscribers.allObjects {
                                    if let subscriber = object as? DataSubscriber {
                                        subscriber.didUpdateFeeds([])
                                    }
                                }
                            }

                            it("stops refreshing") {
                                expect(subject.refreshControl.isRefreshing) == false
                            }

                            it("makes another request for the feeds") {
                                expect(dataUseCase.feedsPromises.count) == 2
                            }

                            it("reloads the tableView when the promise returns") {
                                dataUseCase.feedsPromises.last?.resolve(.success(feeds + [feed3]))
                                expect(subject.tableView.numberOfRows(inSection: 0)) == 2 // cause it was 1
                            }
                        }

                        context("when the call fails") {
                            beforeEach {
                                let error = NSError(domain: "URLErrorDomain", code: -1001, userInfo: [NSLocalizedFailureReasonErrorKey: "The request timed out.", "feedTitle": "foo"])
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
                                expect(subject.refreshControl.isRefreshing) == false
                            }
                            
                            it("should bring up an alert notifying the user") {
                                expect(subject.notificationView.titleLabel.isHidden) == false
                                expect(subject.notificationView.titleLabel.text).to(equal("Unable to update feeds"))
                                expect(subject.notificationView.messageLabel.text).to(equal("foo: The request timed out."))
                            }
                        }

                        context("when the call fails without a feedTitle") {
                            beforeEach {
                                let error = NSError(domain: "RNewsError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Hello"])
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
                                expect(subject.refreshControl.isRefreshing) == false
                            }

                            it("should bring up an alert notifying the user") {
                                expect(subject.notificationView.titleLabel.isHidden) == false
                                expect(subject.notificationView.titleLabel.text).to(equal("Unable to update feeds"))
                                expect(subject.notificationView.messageLabel.text).to(equal("Hello"))
                            }
                        }
                    }

                    describe("as a FeedsSource") {
                        it("returns feeds as the feeds") {
                            expect(subject.feeds) == feeds
                        }

                        describe("deleteFeed") {
                            var receivedFuture: Future<Bool>!
                            beforeEach {
                                receivedFuture = subject.deleteFeed(feed: feed1)
                            }

                            it("returns an in-progress future") {
                                expect(receivedFuture.value).to(beNil())
                            }

                            it("does not yet delete the feed from the data store") {
                                expect(dataUseCase.lastDeletedFeed).to(beNil())
                            }

                            it("presents an alert asking for confirmation that the user wants to do this") {
                                expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                guard let alert = subject.presentedViewController as? UIAlertController else { return }
                                expect(alert.preferredStyle) == UIAlertControllerStyle.alert
                                expect(alert.title) == "Delete \(feed1.displayTitle)?"

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
                                    expect(dataUseCase.lastDeletedFeed) == feed1
                                }

                                it("dismisses the alert") {
                                    expect(subject.presentedViewController).to(beNil())
                                }

                                it("resolves the future with true") {
                                    expect(receivedFuture.value) == true
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

                                it("resolves the future with false") {
                                    expect(receivedFuture.value) == false
                                }
                            }
                        }

                        describe("markRead") {
                            beforeEach {
                                _ = subject.markRead(feed: feed1)
                            }

                            it("marks all articles of that feed as read") {
                                expect(dataUseCase.lastFeedMarkedRead) == feed1
                            }

                            it("when the subscriber gets a marked articles notice it does not refresh it's feed cache") {
                                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [])
                                dataUseCase.subscribersArray.first?.markedArticles([article], asRead: true)
                                expect(dataUseCase.feedsPromises.count) == 1
                            }

                            it("causes a refresh of the feeds") {
                                mainQueue.runSynchronously = true
                                dataUseCase.lastFeedMarkedReadPromise?.resolve(.success(0))
                                expect(dataUseCase.feedsPromises.count) == 2
                            }
                        }

                        describe("editFeed") {
                            it("brings up a feed edit screen") {
                                subject.editFeed(feed: feed1)

                                expect(navigationController.visibleViewController).to(beAnInstanceOf(UINavigationController.self))
                                if let nc = navigationController.visibleViewController as? UINavigationController {
                                    expect(nc.viewControllers.count).to(equal(1))
                                    expect(nc.topViewController).to(beAnInstanceOf(FeedViewController.self))
                                }
                            }
                        }

                        describe("shareFeed") {
                            it("brings up a share sheet") {
                                subject.shareFeed(feed: feed1)
                                expect(navigationController.visibleViewController).to(beAnInstanceOf(UIActivityViewController.self))
                                if let activityVC = navigationController.visibleViewController as? UIActivityViewController {
                                    expect(activityVC.activityItems as? [URL]) == [feed1.url]
                                }
                            }
                        }
                    }
                }

                context("but no feeds were found") {
                    beforeEach {
                        dataUseCase.feedsPromises.first?.resolve(.success([]))
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
                    dataUseCase.feedsPromises.first?.resolve(.failure(.unknown))
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
                    expect(subject.notificationView.titleLabel.isHidden) == false
                    expect(subject.notificationView.titleLabel.text) == "Error"
                    expect(subject.notificationView.messageLabel.text) == "Unknown Error"
                }
            }
        }
    }
}
