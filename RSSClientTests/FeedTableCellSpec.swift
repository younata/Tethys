import Quick
import Nimble
import UIKit
import rNews
import rNewsKit

class FeedTableCellSpec: QuickSpec {
    override func spec() {
        var subject: FeedTableCell! = nil
        var themeRepository: FakeThemeRepository! = nil
        beforeEach {
            subject = FeedTableCell(style: .Default, reuseIdentifier: nil)
            themeRepository = FakeThemeRepository()
            subject.themeRepository = themeRepository
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("updates the labels") {
                expect(subject.nameLabel.textColor).to(equal(themeRepository.textColor))
                expect(subject.summaryLabel.textColor).to(equal(themeRepository.textColor))
            }

            it("changes the background color") {
                expect(subject.backgroundColor).to(equal(themeRepository.backgroundColor))
            }
        }

        sharedExamples("a standard feed cell") {(ctx: SharedExampleContext) in
            var subject: FeedTableCell! = nil
            it("sets the title") {
                subject = ctx()["subject"] as! FeedTableCell
                let title = ctx()["title"] as! String
                expect(subject.nameLabel.text).to(equal(title))
            }

            it("sets the summary") {
                subject = ctx()["subject"] as! FeedTableCell
                let summary = ctx()["summary"] as? String ?? ""
                expect(subject.summaryLabel.text).to(equal(summary))
            }
        }

        describe("setting feed") {
            var feed: Feed! = nil
            context("with a feed that has no unread articles") {
                beforeEach {
                    feed = Feed(title: "Hello", url: nil, summary: "World", query: nil, tags: [],
                        waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    subject.feed = feed
                }

                itBehavesLike("a standard feed cell") {
                    ["subject": subject, "title": "Hello", "summary": "World"]
                }

                it("should hide the unread counter") {
                    expect(subject.unreadCounter.hidden).to(beTruthy())
                    expect(subject.unreadCounter.unread).to(equal(0))
                }
            }

            context("with a feed that has some unread articles") {
                beforeEach {
                    let article1 = Article(title: "a", link: nil, summary: "", author: "",
                        published: NSDate(), updatedAt: nil, identifier: "", content: "",
                        read: true, feed: nil, flags: [], enclosures: [])
                    let article2 = Article(title: "b", link: nil, summary: "", author: "",
                        published: NSDate(), updatedAt: nil, identifier: "", content: "",
                        read: false, feed: nil, flags: [], enclosures: [])
                    feed = Feed(title: "Hello", url: nil, summary: "World", query: nil, tags: [],
                        waitPeriod: 0, remainingWait: 0, articles: [article1, article2], image: nil)
                    subject.feed = feed
                }
                itBehavesLike("a standard feed cell") {
                    ["subject": subject, "title": "Hello", "summary": "World"]
                }

                it("should hide the unread counter") {
                    expect(subject.unreadCounter.hidden).to(beFalsy())
                    expect(subject.unreadCounter.unread).to(equal(1))
                }
            }

            context("with a feed featuring an image") {
                var image: UIImage! = nil
                beforeEach {
                    let data = NSData(contentsOfURL: NSURL(string: "https://avatars3.githubusercontent.com/u/285321?v=3&s=40")!)!
                    image = UIImage(data: data)
                    feed = Feed(title: "Hello", url: nil, summary: "World", query: nil, tags: [],
                        waitPeriod: 0, remainingWait: 0, articles: [], image: image)
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
                    feed = Feed(title: "Hello", url: nil, summary: "World", query: nil, tags: [],
                        waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
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
