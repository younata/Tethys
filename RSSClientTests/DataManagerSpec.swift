import Quick
import Nimble
import Ra
import CoreData
@testable import rNewsKit

class DataManagerSpec: QuickSpec {
    override func spec() {
        var subject: DataManager! = nil
        var injector: Ra.Injector! = nil

        var moc: NSManagedObjectContext! = nil

        var backgroundQueue: FakeOperationQueue! = nil
        var mainQueue: FakeOperationQueue! = nil

        var urlSession: FakeURLSession! = nil

        var feed1: CoreDataFeed! = nil
        var feed2: CoreDataFeed! = nil
        var feed3: CoreDataFeed! = nil

        var article1: CoreDataArticle! = nil
        var article2: CoreDataArticle! = nil

        var searchIndex: FakeSearchIndex! = nil

        beforeEach {
            moc = managedObjectContext()

            backgroundQueue = FakeOperationQueue()
            mainQueue = FakeOperationQueue()
            for queue in [backgroundQueue, mainQueue] {
                queue.runSynchronously = true
            }
            injector = Ra.Injector()
            injector.bind(kBackgroundQueue, to: backgroundQueue)
            injector.bind(kMainQueue, to: mainQueue)

            urlSession = FakeURLSession()
            injector.bind(NSURLSession.self, to: urlSession)

            if #available(iOS 9.0, *) {
                searchIndex = FakeSearchIndex()
                injector.bind(SearchIndex.self, to: searchIndex)
            }

            subject = injector.create(DataManager.self) as! DataManager
            subject.backgroundObjectContext = moc

            // seed with a few feeds/articles/enclosures

            feed1 = createFeed(moc)
            feed1.title = "a"
            feed1.url = "https://example.com/feed1.feed"
            feed1.tags = ["a", "b", "c"]
            article1 = createArticle(moc)
            article1.title = "b"
            article2 = createArticle(moc)
            article2.title = "c"
            article2.read = true
            article1.feed = feed1
            article2.feed = feed1

            feed2 = createFeed(moc) // query feed
            feed2.title = "d"
            feed2.tags = ["b", "d"]
            feed2.query = "return true"

            feed3 = createFeed(moc)
            feed3.title = "e"
            feed3.url = "https://example.com/feed3.feed"
            feed3.remainingWait = 1
            feed3.tags = ["dad"]
            do {
                try moc.save()
            } catch _ {
            }
        }

        xdescribe("updating feeds") {
            var didCallCallback = false
            var callbackError: NSError? = nil
            beforeEach {
                didCallCallback = false
                callbackError = nil
                subject.updateFeeds {error in
                    didCallCallback = true
                    callbackError = error
                }
            }

            it("should make a network request for every feed in the data store w/ a url and a remaining wait of 0") {
                expect(urlSession.lastURL?.absoluteString).to(equal("https://example.com/feed1.feed"))
            }

            context("when the network request succeeds") {
                context("when the network call succeeds") {
                    beforeEach {
                        let urlResponse = NSHTTPURLResponse(URL: NSURL(string: "https://example.com/feed1.feed")!, statusCode: 200, HTTPVersion: nil, headerFields: [:])
                        let bundle = NSBundle(forClass: OPMLParserSpec.self)
                        let data = NSData(contentsOfFile: bundle.pathForResource("feed2", ofType: "rss")!)
                        urlSession.lastCompletionHandler(data, urlResponse, nil)
                    }

                    it("should call the completion handler without an error") {
                        expect(didCallCallback).to(beTruthy())
                        expect(callbackError).to(beNil())
                    }

                    it("should update the feed data now") {
                        let updatedFeed = DataUtility.feedsWithPredicate(NSPredicate(format: "url = %@", "https://example.com/feed1.feed"),
                            managedObjectContext: moc).first
                        expect(updatedFeed).toNot(beNil())
                        expect(updatedFeed?.title).to(equal("objc.io"))
                    }

                    it("should set the app badge number to the amount of unread articles") {
                        let app = UIApplication.sharedApplication()
                        expect(app.applicationIconBadgeNumber).to(equal(12))
                    }

                    it("should, on ios 9, add spotlight entries for each added article") {
                        if #available(iOS 9.0, *) {
                            expect(searchIndex.lastItemsAdded.count).toNot(equal(0))
                        }
                    }

                    context("when the feed contains an image") { // which it does
                        it("should try to download it") {
                            expect(urlSession.lastURL?.absoluteString).to(equal("http://example.org/icon.png"))
                        }

                        context("if that succeeds") {
                            var expectedImageData: NSData! = nil
                            beforeEach {
                                let bundle = NSBundle(forClass: self.classForCoder)
                                expectedImageData = NSData(contentsOfURL: bundle.URLForResource("test", withExtension: "jpg")!)
                                urlSession.lastCompletionHandler(expectedImageData, nil, nil)
                            }
                            it("should set the feed's image to that image") {
                                let updatedFeed = DataUtility.feedsWithPredicate(NSPredicate(format: "url = %@", "https://example.com/feed1.feed"),
                                    managedObjectContext: moc).first
                                expect(updatedFeed?.image).toNot(beNil())
                            }
                        }
                    }
                }
            }

            context("when the network call fails due to a network error") {
                let error = NSError(domain: "", code: 0, userInfo: [:])
                beforeEach {
                    urlSession.lastCompletionHandler(nil, nil, error)
                }

                it("should call the completion handler to let the caller know of an error updating the feed") {
                    expect(callbackError).to(equal(error))
                }
            }

            context("when the network call fails due to a client/server error") {
                beforeEach {
                    let urlResponse = NSHTTPURLResponse(URL: NSURL(string: "https://example.com/rnews.feed")!, statusCode: 400, HTTPVersion: nil, headerFields: [:])
                    urlSession.lastCompletionHandler(nil, urlResponse, nil)
                }

                it("should call the completion handler to let the caller know of an error updating the feed") {
                    expect(callbackError?.code).to(equal(400))
                }
            }
        }
    }
}
