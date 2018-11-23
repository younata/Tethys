import Quick
import Nimble
import Tethys
import TethysKit

class UIApplicationTethysSpec: QuickSpec {
    override func spec() {
        var subject: UIApplication! = nil
        var originalBadgeCount: Int = 0

        beforeEach {
            subject = UIApplication.shared
            originalBadgeCount = subject.applicationIconBadgeNumber
            subject.applicationIconBadgeNumber = 1
        }

        afterEach {
            subject.applicationIconBadgeNumber = originalBadgeCount
        }

        it("increments the badge number when an article is marked as unread") {
            let currentBadgeCount = subject.applicationIconBadgeNumber

            let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, feed: nil, flags: [])
            subject.markedArticles([article], asRead: false)

            expect(subject.applicationIconBadgeNumber - currentBadgeCount) == 1
        }

        it("decrements the badge number when an article is marked as read") {
            let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, feed: nil, flags: [])
            subject.markedArticles([article], asRead: true)

            expect(subject.applicationIconBadgeNumber).to(equal(0))
        }

        it("decrements the badge number if an unread article is deleted") {
            let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, feed: nil, flags: [])
            subject.deletedArticle(article)

            expect(subject.applicationIconBadgeNumber).to(equal(0))
        }

        it("does nothing to the badge number if a read article is deleted") {
            let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: true, synced: false, feed: nil, flags: [])
            subject.deletedArticle(article)

            expect(subject.applicationIconBadgeNumber).to(equal(1))
        }

        describe("On update feed start") {
            beforeEach {
                subject.willUpdateFeeds()
            }

            it("shows the network activity indicator") {
                expect(subject.isNetworkActivityIndicatorVisible) == true
            }

            describe("when we stop updating feeds") {
                beforeEach {
                    subject.didUpdateFeeds([])
                }

                it("stops showing the network activity indicator") {
                    expect(subject.isNetworkActivityIndicatorVisible) == false
                }
            }
        }
    }
}
