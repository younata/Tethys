import Quick
import Nimble
import rNews
import rNewsKit
import AppKit

private class FakeFeedViewDelegate: FeedViewDelegate {
    fileprivate var clickedFeed: Feed? = nil
    fileprivate func didClickFeed(_ feed: Feed) {
        clickedFeed = feed
    }

    fileprivate var feedOfRequestedMenuOptions: Feed? = nil
    fileprivate var menuOptions: [String] = []
    fileprivate func menuOptionsForFeed(_ feed: Feed) -> [String] {
        feedOfRequestedMenuOptions = feed
        return menuOptions
    }

    fileprivate var selectedMenuOption: String? = nil
    fileprivate var selectedFeed: Feed? = nil
    fileprivate func didSelectMenuOption(_ menuOption: String, forFeed: Feed) {
        selectedMenuOption = menuOption
        selectedFeed = forFeed
    }

    init() {}
}

class FeedViewSpec: QuickSpec {
    override func spec() {
        var subject: FeedView! = nil

        beforeEach {
            subject = FeedView(frame: NSZeroRect)
        }

        it("correctly configures the unread counter") {
            expect(subject.unreadCounter.hideUnreadText) == false
        }

        describe("gesture recognizers") {
            let feed = Feed(title: "feed", url: URL(string: "https://example.com")!, summary: "feedSummary", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            var delegate: FakeFeedViewDelegate! = nil

            beforeEach {
                delegate = FakeFeedViewDelegate()
                subject.configure(feed, delegate: delegate)
            }

            describe("a single click") {
                beforeEach {
                    subject.mouseUp(with: NSEvent())
                }

                it("should tell its delegate") {
                    expect(delegate.clickedFeed).to(equal(feed))
                }
            }

            describe("a secondary click") {
                var menu: NSMenu? = nil

                let menuOptions = ["first", "second", "third"]

                beforeEach {
                    delegate.menuOptions = menuOptions
                    menu = subject.menu(for: NSEvent())
                }

                it("should ask for menu options") {
                    expect(delegate.feedOfRequestedMenuOptions).to(equal(feed))
                }

                it("should return a non-nil menu") {
                    expect(menu).toNot(beNil())
                    guard let menu = menu else {
                        return
                    }
                    expect(menu.items.count).to(equal(menuOptions.count))

                    for (idx, menuItem) in menu.items.enumerated() {
                        expect(menuItem.title).to(equal(menuOptions[idx]))
                    }
                }

                describe("selecting a menu item") {
                    beforeEach {
                        guard let item = menu?.item(at: 1) else {
                            fail("unknown menu item")
                            return
                        }
                        if let target = item.target as? NSObject {
                            target.perform(item.action!, with: item)
                        }
                    }

                    it("should notify its delegate") {
                        expect(delegate.selectedMenuOption) == "second"
                        expect(delegate.selectedFeed) == feed
                    }
                }
            }
        }

        sharedExamples("a configured feedView") {(sharedContext: @escaping SharedExampleContext) in
            it("title") {
                let expectedTitle = sharedContext()["title"] as? String
                expect(expectedTitle).toNot(beNil())
                expect(subject.nameLabel.string).to(equal(expectedTitle))
            }

            it("summary") {
                let expectedSummary = sharedContext()["summary"] as? String
                expect(expectedSummary).toNot(beNil())
                expect(subject.summaryLabel.string).to(equal(expectedSummary))
            }

            it("unread") {
                let expectedUnread = sharedContext()["unread"] as? Int
                expect(expectedUnread).toNot(beNil())

                if let unread = expectedUnread {
                    expect(subject.unreadCounter.unread).to(equal(UInt(unread)))
                }
            }

            it("image") {
                let expectedImage = sharedContext()["image"] as? NSImage
                if let _ = expectedImage {
                    expect(subject.imageView.image).to(equal(expectedImage))
                } else {
                    expect(subject.imageView.image).to(beNil())
                }
            }
        }

        context("when configured with a standard feed") {
            let feed = Feed(title: "feed", url: URL(string: "https://example.com")!, summary: "feedSummary", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            beforeEach {
                subject.configure(feed, delegate: FakeFeedViewDelegate())
            }

            itBehavesLike("a configured feedView") {
                return [
                    "title": feed.title,
                    "summary": feed.displaySummary,
                    "unread": 0
                ]
            }
        }

        context("when configured with a feed with unread articles") {
            let article1 = Article(title: "a", link: URL(string: "https://example.com/1")!, summary: "", authors: [],
                published: Date(), updatedAt: nil, identifier: "", content: "",
                read: true, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])
            let article2 = Article(title: "b", link: URL(string: "https://example.com/2")!, summary: "", authors: [],
                published: Date(), updatedAt: nil, identifier: "", content: "",
                read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])
            let feed = Feed(title: "Hello", url: URL(string: "https://example.com")!, summary: "World", tags: [],
                waitPeriod: 0, remainingWait: 0, articles: [article1, article2], image: nil)

            beforeEach {
                subject.configure(feed, delegate: FakeFeedViewDelegate())
            }

            itBehavesLike("a configured feedView") {
                return [
                    "title": feed.title,
                    "summary": feed.displaySummary,
                    "unread": 1
                ]
            }
        }

        context("when configured with a feed containing an image") {
            var feed: Feed! = nil

            beforeEach {
                let image = NSImage(named: "GrayIcon")
                feed = Feed(title: "feed", url: URL(string: "https://example.com")!, summary: "feedSummary", tags: [],
                    waitPeriod: 0, remainingWait: 0, articles: [], image: image)
                subject.configure(feed, delegate: FakeFeedViewDelegate())
            }

            itBehavesLike("a configured feedView") {
                return [
                    "title": feed.title,
                    "summary": feed.displaySummary,
                    "unread": 0,
                    "image": feed.image!
                ]
            }
        }
    }
}
