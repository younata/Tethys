import Quick
import Nimble
import UIKit
import Tethys
import TethysKit

class FeedTableCellSpec: QuickSpec {
    override func spec() {
        var subject: FeedTableCell! = nil
        beforeEach {
            subject = FeedTableCell(style: .default, reuseIdentifier: nil)
        }

        describe("theming") {
            it("sets the labels") {
                expect(subject.nameLabel.textColor).to(equal(Theme.textColor))
                expect(subject.summaryLabel.textColor).to(equal(Theme.textColor))
            }

            it("sets the background color") {
                expect(subject.backgroundColor).to(equal(Theme.backgroundColor))
            }

            it("sets the unreadCounter's colors") {
                expect(subject.unreadCounter.triangleColor).to(equal(Theme.highlightColor))
            }
        }

        func itBehavesLikeAStandardFeedCell(title: String, summary: String, unreadString: String, cellProvider: @escaping () -> FeedTableCell) {
            it("sets the title") {
                expect(cellProvider().nameLabel.text).to(equal(title))
            }

            it("sets the summary") {
                expect(cellProvider().summaryLabel.text).to(equal(summary))
            }

            it("sets the accessibility information") {
                expect(cellProvider().accessibilityLabel).to(equal("Feed"))
                expect(cellProvider().accessibilityValue).to(equal("\(title). \(unreadString)"))
                expect(cellProvider().accessibilityTraits).to(equal([.button]))
            }

            it("is an accessibility element") {
                expect(cellProvider().isAccessibilityElement).to(beTrue())
            }
        }

        describe("setting feed") {
            var feed: Feed! = nil
            context("with a feed that has no unread articles") {
                beforeEach {
                    feed = Feed(title: "Hello", url: URL(string: "https://example.com")!, summary: "World", tags: [],
                        unreadCount: 0, image: nil)
                    subject.feed = feed
                }

                itBehavesLikeAStandardFeedCell(title: "Hello", summary: "World", unreadString: "0 unread articles") { subject }

                it("hides the unread counter") {
                    expect(subject.unreadCounter.isHidden) == true
                    expect(subject.unreadCounter.unread).to(equal(0))
                }
            }

            context("with a feed that has some unread articles") {
                beforeEach {
                    feed = Feed(title: "Hello", url: URL(string: "https://example.com")!, summary: "World", tags: [],
                                unreadCount: 1, image: nil)
                    subject.feed = feed
                }
                itBehavesLikeAStandardFeedCell(title: "Hello", summary: "World", unreadString: "1 unread article") { subject }

                it("hides the unread counter") {
                    expect(subject.unreadCounter.isHidden) == false
                    expect(subject.unreadCounter.unread).to(equal(1))
                }
            }

            context("with a feed featuring an image") {
                var image: UIImage! = nil
                beforeEach {
                    image = UIImage(named: "GrayIcon")
                    feed = Feed(title: "Hello", url: URL(string: "https://example.com")!, summary: "World", tags: [],
                        unreadCount: 2, image: image)
                    subject.feed = feed
                }

                itBehavesLikeAStandardFeedCell(title: "Hello", summary: "World", unreadString: "2 unread articles") { subject }

                it("shows the image") {
                    expect(subject.iconView.image).to(equal(image))
                }

                it("sets the width or height constraint depending on the image size") {
                    // in this case, 60x60
                    expect(subject.iconWidth.constant).to(equal(60))
                    expect(subject.iconHeight.constant).to(equal(60))
                }
            }

            context("with a feed that doesn't have an image") {
                beforeEach {
                    feed = Feed(title: "Hello", url: URL(string: "https://example.com")!, summary: "World", tags: [],
                        unreadCount: 3, image: nil)
                    subject.feed = feed
                }

                itBehavesLikeAStandardFeedCell(title: "Hello", summary: "World", unreadString: "3 unread articles") { subject }

                it("sets an image of nil") {
                    expect(subject.iconView.image).to(beNil())
                }

                it("sets the width to 45 and the height to 0") {
                    expect(subject.iconWidth.constant).to(equal(45))
                    expect(subject.iconHeight.constant).to(equal(0))
                }
            }
        }
    }
}
