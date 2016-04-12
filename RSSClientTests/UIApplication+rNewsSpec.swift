import Quick
import Nimble
import rNews
import rNewsKit

class UIApplicationRNewsSpec: QuickSpec {
    override func spec() {
        var subject: UIApplication! = nil
        var originalBadgeCount: Int = 0

        beforeEach {
            subject = UIApplication.sharedApplication()
            originalBadgeCount = subject.applicationIconBadgeNumber
            subject.applicationIconBadgeNumber = 1
        }

        afterEach {
            subject.applicationIconBadgeNumber = originalBadgeCount
        }

        it("increments the badge number when an article is marked as unread") {
            let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
            subject.markedArticles([article], asRead: false)

            expect(subject.applicationIconBadgeNumber).to(equal(2))
        }

        it("decrements the badge number when an article is marked as read") {
            let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
            subject.markedArticles([article], asRead: true)

            expect(subject.applicationIconBadgeNumber).to(equal(0))
        }

        it("decrements the badge number if an unread article is deleted") {
            let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
            subject.deletedArticle(article)

            expect(subject.applicationIconBadgeNumber).to(equal(0))
        }

        it("does nothing to the badge number if a read article is deleted") {
            let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: true, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
            subject.deletedArticle(article)

            expect(subject.applicationIconBadgeNumber).to(equal(1))
        }

        describe("On update feed start") {
            beforeEach {
                subject.willUpdateFeeds()
            }

            it("shows the network activity indicator") {
                expect(subject.networkActivityIndicatorVisible) == true
            }

            describe("when we stop updating feeds") {
                beforeEach {
                    subject.didUpdateFeeds([])
                }

                it("stops showing the network activity indicator") {
                    expect(subject.networkActivityIndicatorVisible) == false
                }
            }
        }
    }
}