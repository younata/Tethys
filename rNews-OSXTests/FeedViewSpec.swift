import Quick
import Nimble
import rNews
import rNewsKit
import AppKit

private class FakeFeedViewDelegate: FeedViewDelegate {
    private var clickedFeed: Feed? = nil
    private func didClickFeed(feed: Feed) {
        clickedFeed = feed
    }

    private var feedOfRequestedMenuOptions: Feed? = nil
    private var menuOptions: [String] = []
    private func menuOptionsForFeed(feed: Feed) -> [String] {
        feedOfRequestedMenuOptions = feed
        return menuOptions
    }

    private var selectedMenuOption: String? = nil
    private var selectedFeed: Feed? = nil
    private func didSelectMenuOption(menuOption: String, forFeed: Feed) {
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
            let feed = Feed(title: "feed", url: nil, summary: "feedSummary", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            var delegate: FakeFeedViewDelegate! = nil

            beforeEach {
                delegate = FakeFeedViewDelegate()
                subject.configure(feed, delegate: delegate)
            }

            describe("a single click") {
                beforeEach {
                    subject.mouseUp(NSEvent())
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
                    menu = subject.menuForEvent(NSEvent())
                }

                it("should ask for menu options") {
                    expect(delegate.feedOfRequestedMenuOptions).to(equal(feed))
                }

                it("should return a non-nil menu") {
                    expect(menu).toNot(beNil())
                    guard let menu = menu else {
                        return
                    }
                    expect(menu.itemArray.count).to(equal(menuOptions.count))

                    for (idx, menuItem) in menu.itemArray.enumerate() {
                        expect(menuItem.title).to(equal(menuOptions[idx]))
                    }
                }

                describe("selecting a menu item") {
                    beforeEach {
                        guard let item = menu?.itemAtIndex(1) else {
                            return
                        }
                        if let target = item.target as? NSObject {
                            target.performSelector(item.action, withObject: item)
                        }
                    }

                    it("should notify its delegate") {
                        expect(delegate.selectedMenuOption).to(equal("second"))
                        expect(delegate.selectedFeed).to(equal(feed))
                    }
                }
            }
        }

        sharedExamples("a configured feedView") {(sharedContext: SharedExampleContext) in
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
            let feed = Feed(title: "feed", url: nil, summary: "feedSummary", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

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
            let article1 = Article(title: "a", link: nil, summary: "", authors: [],
                published: NSDate(), updatedAt: nil, identifier: "", content: "",
                read: true, feed: nil, flags: [], enclosures: [])
            let article2 = Article(title: "b", link: nil, summary: "", authors: [],
                published: NSDate(), updatedAt: nil, identifier: "", content: "",
                read: false, feed: nil, flags: [], enclosures: [])
            let feed = Feed(title: "Hello", url: nil, summary: "World", query: nil, tags: [],
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
                let data = NSData(contentsOfURL: NSURL(string: "https://avatars3.githubusercontent.com/u/285321?v=3&s=40")!)!
                let image = NSImage(data: data)
                feed = Feed(title: "feed", url: nil, summary: "feedSummary", query: nil, tags: [],
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