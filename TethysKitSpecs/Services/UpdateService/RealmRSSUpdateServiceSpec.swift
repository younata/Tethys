import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP
import RealmSwift

@testable import TethysKit

final class RealmRSSUpdateServiceSpec: QuickSpec {
    override func spec() {
        var subject: RealmRSSUpdateService!

        var httpClient: FakeHTTPClient!
        var mainQueue: FakeOperationQueue!
        var workQueue: FakeOperationQueue!

        let realmConf = Realm.Configuration(inMemoryIdentifier: "RealmArticleServiceSpec")
        var realm: Realm!

        var realmFeed: RealmFeed!

        func write(_ transaction: () -> Void) {
            realm.beginWrite()

            transaction()

            do {
                try realm.commitWrite()
            } catch let exception {
                dump(exception)
                fail("Error writing to realm: \(exception)")
            }
        }

        beforeEach {
            let realmProvider = DefaultRealmProvider(configuration: realmConf)
            realm = realmProvider.realm()
            try! realm.write {
                realm.deleteAll()
            }

            httpClient = FakeHTTPClient()

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            workQueue = FakeOperationQueue()
            workQueue.runSynchronously = true

            subject = RealmRSSUpdateService(
                httpClient: httpClient,
                realmProvider: realmProvider,
                mainQueue: mainQueue,
                workQueue: workQueue
            )

            write {
                realmFeed = RealmFeed()

                realmFeed.title = "Feed"
                realmFeed.url = "https://example.com/feed/feed"

                realm.add(realmFeed)
            }
        }

        describe("updateFeed()") {
            var future: Future<Result<TethysKit.Feed, TethysError>>!

            context("when the feed doesn't exist in the database") {
                beforeEach {
                    future = subject.updateFeed(feedFactory())
                }

                it("resolves saying it couldn't find the feed in the database") {
                    expect(future.value?.error).to(equal(.database(.entryNotFound)))
                }
            }

            context("when the feed exists in the database") {
                beforeEach {
                    future = subject.updateFeed(Feed(realmFeed: realmFeed))
                }

                it("asks the http client for the contents at the feed's url") {
                    expect(httpClient.requests).to(haveCount(1))

                    guard let request = httpClient.requests.last else { return }

                    expect(request.url).to(equal(URL(string: "https://example.com/feed/feed")!))
                    expect(request.httpMethod).to(equal("GET"))
                }

                describe("when the request succeeds") {
                    let dateFormatter = ISO8601DateFormatter()

                    func resolvePromise(feed: String) {
                        let location = Bundle(for: self.classForCoder).url(forResource: feed, withExtension: "rss")!
                        let response = HTTPResponse(
                            body: try! Data(contentsOf: location),
                            status: .ok,
                            mimeType: "",
                            headers: [:]
                        )

                        httpClient.requestPromises.last?.resolve(.success(response))
                    }

                    context("if the downloaded feed data has no image url") {
                        beforeEach {
                            resolvePromise(feed: "feed")
                        }

                        it("Updates the feed's information based on the downloaded feed") {
                            expect(realmFeed.title).to(equal("Rachel Brindle"))
                            expect(realmFeed.url).to(equal("https://example.com/feed/feed"))
                            expect(realmFeed.summary).to(equal("Software Engineer and Electric Vehicle enthusiast"))
                        }

                        it("inserts articles for each article in the feed") {
                            expect(realmFeed.articles).to(haveCount(10))

                            guard let article = realmFeed.articles.sorted(byKeyPath: "published", ascending: false).first else { return }
                            expect(article.title).to(equal("MKOverlayRenderer - Drawing Lines"))
                            expect(article.summary).to(contain("Today, I spent roughly 5 hours"))
                            expect(article.content).to(equal(""))
                            expect(article.published).to(equal(dateFormatter.date(from: "2018-09-16T00:00:00Z")!))
                            expect(article.identifier).to(beNil())
                            expect(article.link).to(equal("http://younata.github.io/2018/09/16/MKOverlayRenderer-drawing-lines/"))
                            expect(article.authors).to(haveCount(1))
                        }

                        it("inserts any new authors into the list") {
                            let authors = realm.objects(RealmAuthor.self)

                            expect(authors).to(haveCount(1))

                            expect(authors.first?.email).to(beNil())
                            expect(authors.first?.name).to(equal("Rachel Brindle"))
                        }

                        it("resolves the promise with the now-updated feed") {
                            expect(future.value?.value).to(equal(
                                Feed(
                                    title: "Rachel Brindle",
                                    url: URL(string: "https://example.com/feed/feed")!,
                                    summary: "Software Engineer and Electric Vehicle enthusiast",
                                    tags: []
                                )
                            ))
                        }

                        describe("updating the feed again") {
                            beforeEach {
                                _ = subject.updateFeed(Feed(realmFeed: realmFeed))

                                resolvePromise(feed: "feed")
                            }

                            it("doesn't add duplicate articles") {
                                expect(realmFeed.articles).to(haveCount(10))
                            }

                            it("doesn't add duplicate authors") {
                                expect(realm.objects(RealmAuthor.self)).to(haveCount(1))
                            }
                        }
                    }

                    context("if the downloaded feed data has an image url and the feed already has an image associated with it") {
                        beforeEach {
                            write {
                                let image = Bundle(for: self.classForCoder).url(forResource: "test", withExtension: "jpg")!
                                realmFeed.imageData = try! Data(contentsOf: image)
                            }

                            resolvePromise(feed: "feed2")
                        }

                        it("Updates the feed's information based on the downloaded feed") {
                            expect(realmFeed.title).to(equal("objc.io"))
                            expect(realmFeed.url).to(equal("https://example.com/feed/feed"))
                            expect(realmFeed.summary).to(equal("A periodical about best practices and advanced techniques for iOS and OS X development."))
                        }

                        it("inserts articles for each article in the feed") {
                            expect(realmFeed.articles).to(haveCount(11))
                        }

                        it("does not make a request for the image url") {
                            expect(httpClient.requests).to(haveCount(1))
                        }

                        it("resolves the promise with the now-updated feed") {
                            expect(future.value?.value).to(equal(
                                Feed(
                                    title: "objc.io",
                                    url: URL(string: "https://example.com/feed/feed")!,
                                    summary: "A periodical about best practices and advanced techniques for iOS and OS X development.",
                                    tags: []
                                )
                            ))
                        }
                    }

                    context("if the downloaded feed data has an image url and the feed doesn't have an image associated with it") {
                        beforeEach {
                            resolvePromise(feed: "feed2")
                        }

                        it("Updates the feed's information based on the downloaded feed") {
                            expect(realmFeed.title).to(equal("objc.io"))
                            expect(realmFeed.url).to(equal("https://example.com/feed/feed"))
                            expect(realmFeed.summary).to(equal("A periodical about best practices and advanced techniques for iOS and OS X development."))
                        }

                        it("inserts articles for each article in the feed") {
                            expect(realmFeed.articles).to(haveCount(11))
                        }

                        it("makes a request for the image url") {
                            expect(httpClient.requests).to(haveCount(2))

                            guard let request = httpClient.requests.last else { return }

                            expect(request.url).to(equal(URL(string: "http://example.org/icon.png")!))
                            expect(request.httpMethod).to(equal("GET"))
                        }

                        it("does not yet resolve the future") {
                            expect(future.value).to(beNil())
                        }

                        describe("when the image url request succeeds") {
                            beforeEach {
                                guard httpClient.requests.count == 2 else { return }

                                let imageURL = Bundle(for: self.classForCoder).url(forResource: "test", withExtension: "jpg")!
                                let response = HTTPResponse(
                                    body: try! Data(contentsOf: imageURL),
                                    status: .ok,
                                    mimeType: "",
                                    headers: [:]
                                )

                                httpClient.requestPromises.last?.resolve(.success(response))
                            }

                            it("saves the image for later use") {
                                expect(realmFeed.imageData).toNot(beNil())
                            }

                            it("resolves the promise with the now-updated feed") {
                                expect(future.value?.value).to(equal(
                                    Feed(
                                        title: "objc.io",
                                        url: URL(string: "https://example.com/feed/feed")!,
                                        summary: "A periodical about best practices and advanced techniques for iOS and OS X development.",
                                        tags: []
                                    )
                                ))
                            }
                        }

                        describe("when the image url request fails") {
                            beforeEach {
                                guard httpClient.requests.count == 2 else { return }

                                httpClient.requestPromises.last?.resolve(.failure(.network(.timedOut)))
                            }

                            it("resolves the promise with the now-updated feed") {
                                expect(future.value?.value).to(equal(
                                    Feed(
                                        title: "objc.io",
                                        url: URL(string: "https://example.com/feed/feed")!,
                                        summary: "A periodical about best practices and advanced techniques for iOS and OS X development.",
                                        tags: []
                                    )
                                ))
                            }
                        }
                    }
                }

                describe("when the request fails") {
                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.failure(.network(.timedOut)))
                    }

                    it("resolves the promise and transforms the error") {
                        expect(future.value?.error).to(equal(TethysError.network(URL(string: "https://example.com/feed/feed")!, .timedOut)))
                    }
                }
            }
        }
    }
}
