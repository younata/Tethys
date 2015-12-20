import Quick
import Nimble
import Ra
import rNews
import rNewsKit

private class FakeTimer: Timer {
    private var timerCallback: ((Void) -> (Void))? = nil
    private override func setTimer(interval: NSTimeInterval, callback: (Void) -> (Void)) {
        self.timerCallback = callback
    }

    private var timerCancelled = false
    private override func cancel() {
        self.timerCancelled = true
    }
}

class BackgroundFetchHandlerSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil
        var dataReadWriter: FakeDataReadWriter! = nil
        var timer: FakeTimer! = nil

        var subject: BackgroundFetchHandler! = nil

        beforeEach {
            injector = Injector()
            dataReadWriter = FakeDataReadWriter()
            dataReadWriter.feedsList = []
            injector.bind(DataRetriever.self, to: dataReadWriter)
            injector.bind(DataWriter.self, to: dataReadWriter)

            timer = FakeTimer()
            injector.bind(Timer.self, to: timer)

            subject = injector.create(BackgroundFetchHandler.self) as! BackgroundFetchHandler
        }

        describe("updating feeds") {
            var notificationHandler: NotificationHandler! = nil
            var notificationSource: FakeNotificationSource! = nil
            var fetchResult: UIBackgroundFetchResult? = nil

            beforeEach {
                notificationHandler = NotificationHandler()
                notificationSource = FakeNotificationSource()
                subject.performFetch(notificationHandler, notificationSource: notificationSource, completionHandler: {res in
                    fetchResult = res
                })
            }

            it("should make a network request") {
                expect(dataReadWriter.didUpdateFeeds).to(beTruthy())
            }

            it("should set up a timer") {
                expect(timer.timerCallback).toNot(beNil())
                expect(timer.timerCancelled).to(beFalsy())
            }

            context("when new articles are found") {
                var articles: [Article] = []
                var feeds: [Feed] = []
                beforeEach {
                    let feed1 = Feed(title: "a", url: nil, summary: "", query: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feed2 = Feed(title: "b", url: nil, summary: "", query: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                    let article1 = Article(title: "a", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "a", content: "", read: false, feed: feed1, flags: [], enclosures: [])
                    let article2 = Article(title: "b", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "b", content: "", read: false, feed: feed1, flags: [], enclosures: [])
                    let article3 = Article(title: "c", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "c", content: "", read: false, feed: feed2, flags: [], enclosures: [])
                    let article4 = Article(title: "d", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "d", content: "", read: false, feed: feed2, flags: [], enclosures: [])

                    feed1.addArticle(article1)
                    feed1.addArticle(article2)
                    feed2.addArticle(article3)
                    feed2.addArticle(article4)

                    feeds = [feed1, feed2]
                    articles = [article1, article2, article3, article4]

                    dataReadWriter.feedsList = feeds // TODO: more than 1
                    dataReadWriter.updateFeedsCompletion(feeds, [])
                }

                it("should cancel the timer") {
                    expect(timer.timerCancelled).to(beTruthy())
                }

                it("should send local notifications for each new article") {
                    expect(notificationSource.scheduledNotes.count).to(equal(articles.count))
                }

                it("should call the completion handler and indicate that there was new data found") {
                    expect(fetchResult).to(equal(UIBackgroundFetchResult.NewData))
                }
            }

            context("when no new articles are found") {
                beforeEach {
                    dataReadWriter.updateFeedsCompletion([], [])
                }

                it("should cancel the timer") {
                    expect(timer.timerCancelled).to(beTruthy())
                }

                it("should not send any new local notifications") {
                    expect(notificationSource.scheduledNotes).to(beEmpty())
                }

                it("should call the completion handler and indicate that there was no new data found") {
                    expect(fetchResult).to(equal(UIBackgroundFetchResult.NoData))
                }
            }

            context("when there is an error updating feeds") {
                beforeEach {
                    dataReadWriter.updateFeedsCompletion([], [NSError(domain: "", code: 0, userInfo: nil)])
                }

                it("should cancel the timer") {
                    expect(timer.timerCancelled).to(beTruthy())
                }

                it("should not send any new local notifications") {
                    expect(notificationSource.scheduledNotes).to(beEmpty())
                }

                it("should call the completion handler and indicate that there was an error") {
                    expect(fetchResult).to(equal(UIBackgroundFetchResult.Failed))
                }
            }

            context("when we get dangerously close to being killed by the app") {
                beforeEach {
                    timer.timerCallback?()
                }

                it("should cancel everything") {
                    expect(dataReadWriter.didCancelFeeds).to(beTruthy())
                }

                it("should report an error") {
                    expect(fetchResult).to(equal(UIBackgroundFetchResult.Failed))
                }
            }
        }
    }
}
