import Quick
import Nimble
import UIKit
import Tethys
import TethysKit

class FeedTableCellSpec: QuickSpec {
    override func spec() {
        var subject: FeedTableCell! = nil
        var themeRepository: ThemeRepository! = nil
        beforeEach {
            subject = FeedTableCell(style: .default, reuseIdentifier: nil)
            themeRepository = ThemeRepository(userDefaults: nil)
            subject.themeRepository = themeRepository
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("updates the labels") {
                expect(subject.nameLabel.textColor).to(equal(themeRepository.textColor))
                expect(subject.summaryLabel.textColor).to(equal(themeRepository.textColor))
            }

            it("changes the background color") {
                expect(subject.backgroundColor).to(equal(themeRepository.backgroundColor))
            }
        }

        sharedExamples("a standard feed cell") {(ctx: @escaping SharedExampleContext) in
            var subject: FeedTableCell! = nil
            it("sets the title") {
                subject = ctx()["subject"] as? FeedTableCell
                let title = ctx()["title"] as! String
                expect(subject.nameLabel.text).to(equal(title))
            }

            it("sets the summary") {
                subject = ctx()["subject"] as? FeedTableCell
                let summary = ctx()["summary"] as? String ?? ""
                expect(subject.summaryLabel.text).to(equal(summary))
            }
        }

        describe("setting feed") {
            var feed: Feed! = nil
            context("with a feed that has no unread articles") {
                beforeEach {
                    feed = Feed(title: "Hello", url: URL(string: "https://example.com")!, summary: "World", tags: [],
                        articles: [], image: nil)
                    subject.feed = feed
                }

                itBehavesLike("a standard feed cell") {
                    ["subject": subject, "title": "Hello", "summary": "World"]
                }

                it("should hide the unread counter") {
                    expect(subject.unreadCounter.isHidden) == true
                    expect(subject.unreadCounter.unread).to(equal(0))
                }
            }

            context("with a feed that has some unread articles") {
                beforeEach {
                    let article1 = Article(title: "a", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [],
                        published: Date(), updatedAt: nil, identifier: "", content: "",
                        read: true, feed: nil)
                    let article2 = Article(title: "b", link: URL(string: "https://exapmle.com/2")!, summary: "", authors: [],
                        published: Date(), updatedAt: nil, identifier: "", content: "",
                        read: false, feed: nil)
                    feed = Feed(title: "Hello", url: URL(string: "https://example.com")!, summary: "World", tags: [],
                        articles: [article1, article2], image: nil)
                    subject.feed = feed
                }
                itBehavesLike("a standard feed cell") {
                    ["subject": subject, "title": "Hello", "summary": "World"]
                }

                it("should hide the unread counter") {
                    expect(subject.unreadCounter.isHidden) == false
                    expect(subject.unreadCounter.unread).to(equal(1))
                }
            }

            context("with a feed featuring an image") {
                var image: UIImage! = nil
                beforeEach {
                    image = UIImage(named: "GrayIcon")
                    feed = Feed(title: "Hello", url: URL(string: "https://example.com")!, summary: "World", tags: [],
                        articles: [], image: image)
                    subject.feed = feed
                }

                itBehavesLike("a standard feed cell") {
                    ["subject": subject, "title": "Hello", "summary": "World"]
                }

                it("should show the image") {
                    expect(subject.iconView.image).to(equal(image))
                }

                it("should set the width or height constraint depending on the image size") {
                    // in this case, 60x60
                    expect(subject.iconWidth.constant).to(equal(60))
                    expect(subject.iconHeight.constant).to(equal(60))
                }
            }

            context("with a feed that doesn't have an image") {
                beforeEach {
                    feed = Feed(title: "Hello", url: URL(string: "https://example.com")!, summary: "World", tags: [],
                        articles: [], image: nil)
                    subject.feed = feed
                }

                itBehavesLike("a standard feed cell") {
                    ["subject": subject, "title": "Hello", "summary": "World"]
                }

                it("should set an image of nil") {
                    expect(subject.iconView.image).to(beNil())
                }

                it("should set the width to 45 and the height to 0") {
                    expect(subject.iconWidth.constant).to(equal(45))
                    expect(subject.iconHeight.constant).to(equal(0))
                }
            }
        }
    }
}
