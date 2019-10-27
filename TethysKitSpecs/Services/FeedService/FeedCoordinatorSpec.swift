import Quick
import Nimble
import Result
import CBGPromise
@testable import TethysKit

final class FeedCoordinatorSpec: QuickSpec {
    override func spec() {
        var subject: FeedCoordinator!

        var localFeedService: FakeLocalFeedService!
        var networkFeedService: FakeFeedService!

        beforeEach {
            localFeedService = FakeLocalFeedService()
            networkFeedService = FakeFeedService()

            subject = FeedCoordinator(
                localFeedService: localFeedService,
                networkFeedServiceProvider: { networkFeedService }
            )
        }

        describe("feeds()") {
            var subscription: Subscription<Result<AnyCollection<Feed>, TethysError>>!

            beforeEach {
                subscription = subject.feeds()
            }

            it("asks the local feed service for the current value") {
                expect(localFeedService.feedsPromises).to(haveCount(1))
            }

            it("does not ask the network feed service to update yet") {
                expect(networkFeedService.feedsPromises).to(beEmpty())
            }

            it("returns the same subscription if you ask for feeds again at this point") {
                expect(subject.feeds()).to(beIdenticalTo(subscription))
            }

            describe("when the local feed service succeeds") {
                let expectedFeeds = [feedFactory(title: "feed1"), feedFactory(title: "feed2")]
                beforeEach {
                    localFeedService.feedsPromises.last?.resolve(.success(AnyCollection(expectedFeeds)))
                }

                it("updates the subscription with the list of feeds") {
                    expect(subscription.value).toNot(beNil(), description: "Expected subscription to be updated")
                    guard let receivedFeeds = subscription.value?.value else {
                        return expect(subscription.value?.value).toNot(beNil(), description: "Expected subscription to be updated with success")
                    }
                    expect(Array(receivedFeeds)).to(equal(expectedFeeds))
                }

                it("does not mark the subscription as finished yet") {
                    expect(subscription.isFinished).to(beFalse())
                }

                it("asks the network feed service for the list of updated feeds") {
                    expect(networkFeedService.feedsPromises).to(haveCount(1))
                }

                it("does not ask the local feed service for more feeds") {
                    expect(localFeedService.feedsPromises).to(haveCount(1))
                }

                it("returns the same subscription if you ask for feeds again at this point") {
                    expect(subject.feeds()).to(beIdenticalTo(subscription))
                }

                describe("when the network feed service succeeds") {
                    let updatedFeeds = [feedFactory(title: "feed3"), feedFactory(title: "feed4")]
                    beforeEach {
                        networkFeedService.feedsPromises.last?.resolve(.success(AnyCollection(updatedFeeds)))
                    }

                    it("does not try to fetch feeds again") {
                        expect(localFeedService.feedsPromises).to(haveCount(1))
                        expect(networkFeedService.feedsPromises).to(haveCount(1))
                    }

                    it("updates the subscription with the list of feeds") {
                        expect(subscription.value).toNot(beNil(), description: "Expected subscription to be updated")
                        guard let receivedFeeds = subscription.value?.value else {
                            return expect(subscription.value?.value).toNot(beNil(), description: "Expected subscription to be updated with success")
                        }
                        expect(Array(receivedFeeds)).to(equal(updatedFeeds))
                    }

                    it("does not finish updates for the subscription") {
                        expect(subscription.isFinished).to(beFalse())
                    }

                    it("tells the local feed service to update") {
                        expect(localFeedService.updateFeedsCalls).to(haveCount(1))
                        guard let call = localFeedService.updateFeedsCalls.last else { return }
                        expect(Array(call)).to(equal(updatedFeeds))
                    }

                    it("returns the same subscription if you ask for feeds again at this point") {
                        expect(subject.feeds()).to(beIdenticalTo(subscription))
                    }

                    describe("when the local feeds update") {
                        let savedFeeds = [
                            feedFactory(title: "feed4"),
                            feedFactory(title: "feed5")
                        ]

                        beforeEach {
                            localFeedService.updateFeedsPromises.last?.resolve(.success(AnyCollection(savedFeeds)))
                        }

                        it("updates the subscription with the results") {
                            expect(subscription.value).toNot(beNil(), description: "Expected subscription to be updated")
                            guard let receivedFeeds = subscription.value?.value else {
                                return expect(subscription.value?.value).toNot(beNil(), description: "Expected subscription to be updated with success")
                            }
                            expect(Array(receivedFeeds)).to(equal(savedFeeds))
                        }

                        it("finishes updates for the subscription") {
                            expect(subscription.isFinished).to(beTrue())
                        }

                        it("returns a new subscription if you ask for feeds again") {
                            expect(subject.feeds()).toNot(beIdenticalTo(subscription))
                        }
                    }

                    describe("when the local feeds fail to update") {
                        beforeEach {
                            localFeedService.updateFeedsPromises.last?.resolve(.failure(.database(.entryNotFound)))
                        }

                        it("finishes updates for the subscription") {
                            expect(subscription.isFinished).to(beTrue())
                        }

                        it("does not update the subscription") {
                            expect(subscription.value).toNot(beNil(), description: "Expected subscription to be updated")
                            guard let receivedFeeds = subscription.value?.value else {
                                return expect(subscription.value?.value).toNot(beNil(), description: "Expected subscription to be updated with success")
                            }
                            expect(Array(receivedFeeds)).to(equal(updatedFeeds))
                        }

                        it("returns a new subscription if you ask for feeds again") {
                            expect(subject.feeds()).toNot(beIdenticalTo(subscription))
                        }
                    }
                }

                describe("when the network feed service fails") {
                    beforeEach {
                        networkFeedService.feedsPromises.last?.resolve(.failure(.network(URL(string: "https://example.com")!, .badResponse)))
                    }

                    it("does not try to fetch feeds again") {
                        expect(localFeedService.feedsPromises).to(haveCount(1))
                        expect(networkFeedService.feedsPromises).to(haveCount(1), description: "Retry logic should be in the feeds service")
                    }

                    it("does not update the subscription list with the failure") {
                        expect(subscription.value).toNot(beNil(), description: "Expected subscription to be updated")
                        guard let receivedFeeds = subscription.value?.value else {
                            return expect(subscription.value?.value).toNot(beNil(), description: "Expected subscription to be updated with success")
                        }
                        expect(Array(receivedFeeds)).to(equal(expectedFeeds))
                    }

                    it("does not tell the local feed service to update") {
                        expect(localFeedService.updateFeedsCalls).to(beEmpty())
                    }

                    it("finishes updates for the subscription") {
                        expect(subscription.isFinished).to(beTrue())
                    }

                    it("returns a new subscription if you ask for feeds again") {
                        expect(subject.feeds()).toNot(beIdenticalTo(subscription))
                    }
                }
            }

            describe("when the local feed service fails") {
                // well, fuck.
                beforeEach {
                    localFeedService.feedsPromises.last?.resolve(.failure(.database(.notFound)))
                }

                it("updates the subscription with the result") {
                    expect(subscription.value).toNot(beNil(), description: "Expected subscription to be updated")
                    expect(subscription.value?.error).to(equal(.database(.notFound)))
                }

                it("asks the network feed service for the list of updated feeds") {
                    expect(networkFeedService.feedsPromises).to(haveCount(1))
                }

                it("does not ask the local feed service for more feeds") {
                    expect(localFeedService.feedsPromises).to(haveCount(1))
                }

                it("returns the same subscription if you ask for feeds again at this point") {
                    expect(subject.feeds()).to(beIdenticalTo(subscription))
                }

                describe("when the network feed service succeeds") {
                    let updatedFeeds = [feedFactory(title: "feed5"), feedFactory(title: "feed6")]
                    beforeEach {
                        networkFeedService.feedsPromises.last?.resolve(.success(AnyCollection(updatedFeeds)))
                    }

                    it("does not try to fetch feeds again") {
                        expect(localFeedService.feedsPromises).to(haveCount(1))
                        expect(networkFeedService.feedsPromises).to(haveCount(1))
                    }

                    it("updates the subscription with the list of feeds") {
                        expect(subscription.value).toNot(beNil(), description: "Expected subscription to be updated")
                        guard let receivedFeeds = subscription.value?.value else {
                            return expect(subscription.value?.value).toNot(beNil(), description: "Expected subscription to be updated with success")
                        }
                        expect(Array(receivedFeeds)).to(equal(updatedFeeds))
                    }

                    it("does not finish updates for the subscription") {
                        expect(subscription.isFinished).to(beFalse())
                    }

                    it("tells the local feed service to update") {
                        expect(localFeedService.updateFeedsCalls).to(haveCount(1))
                        guard let call = localFeedService.updateFeedsCalls.last else { return }
                        expect(Array(call)).to(equal(updatedFeeds))
                    }

                    it("returns the same subscription if you ask for feeds again at this point") {
                        expect(subject.feeds()).to(beIdenticalTo(subscription))
                    }

                    describe("when the local feeds update") {
                        let savedFeeds = [
                            feedFactory(title: "feed4"),
                            feedFactory(title: "feed5")
                        ]

                        beforeEach {
                            localFeedService.updateFeedsPromises.last?.resolve(.success(AnyCollection(savedFeeds)))
                        }

                        it("updates the subscription with the results") {
                            expect(subscription.value).toNot(beNil(), description: "Expected subscription to be updated")
                            guard let receivedFeeds = subscription.value?.value else {
                                return expect(subscription.value?.value).toNot(beNil(), description: "Expected subscription to be updated with success")
                            }
                            expect(Array(receivedFeeds)).to(equal(savedFeeds))
                        }

                        it("returns a new subscription if you ask for feeds again") {
                            expect(subject.feeds()).toNot(beIdenticalTo(subscription))
                        }

                        it("finishes updates for the subscription") {
                            expect(subscription.isFinished).to(beTrue())
                        }
                    }

                    describe("when the local feeds fail to update") {
                        beforeEach {
                            localFeedService.updateFeedsPromises.last?.resolve(.failure(.database(.entryNotFound)))
                        }

                        it("returns a new subscription if you ask for feeds again") {
                            expect(subject.feeds()).toNot(beIdenticalTo(subscription))
                        }

                        it("finishes updates for the subscription") {
                            expect(subscription.isFinished).to(beTrue())
                        }
                    }
                }

                describe("when the network feed service fails") {
                    beforeEach {
                        networkFeedService.feedsPromises.last?.resolve(.failure(.network(URL(string: "https://example.com")!, .badResponse)))
                    }

                    it("does not try to fetch feeds again") {
                        expect(localFeedService.feedsPromises).to(haveCount(1))
                        expect(networkFeedService.feedsPromises).to(haveCount(1), description: "Retry logic should be in the feeds service")
                    }

                    it("updates the subscription list with the new failure") {
                        expect(subscription.value).toNot(beNil(), description: "Expected subscription to be updated")
                        expect(subscription.value?.error).to(equal(.network(URL(string: "https://example.com")!, .badResponse)))
                    }

                    it("tells the local feed service to update") {
                        expect(localFeedService.updateFeedsCalls).to(beEmpty())
                    }

                    it("returns a new subscription if you ask for feeds again") {
                        expect(subject.feeds()).toNot(beIdenticalTo(subscription))
                    }

                    it("finishes updates for the subscription") {
                        expect(subscription.isFinished).to(beTrue())
                    }
                }
            }
        }

        describe("articles(of:)") {
            var subscription: Subscription<Result<AnyCollection<Article>, TethysError>>!
            let feed = feedFactory()

            beforeEach {
                subscription = subject.articles(of: feed)
            }

            it("asks the local feed service for articles") {
                expect(localFeedService.articlesOfFeedCalls).to(equal([feed]))
            }

            it("returns the same subscription if you ask for this information twice") {
                expect(subject.articles(of: feed)).to(beIdenticalTo(subscription))
                expect(subject.articles(of: feedFactory(title: "other feed"))).toNot(beIdenticalTo(subscription))
            }

            it("does not yet ask the network feed service for articles") {
                expect(networkFeedService.articlesOfFeedCalls).to(beEmpty())
            }

            context("when the local feed service succeeds") {
                let expectedArticles = [
                    articleFactory(title: "article 1"),
                    articleFactory(title: "article 2")
                ]

                beforeEach {
                    localFeedService.articlesOfFeedPromises.last?.resolve(.success(AnyCollection(expectedArticles)))
                }

                it("updates the subscription with the list of feeds") {
                    expect(subscription.isFinished).to(beFalse())
                    expect(subscription.value).toNot(beNil())
                    guard let receivedArticles = subscription.value?.value else {
                        return expect(subscription.value?.error).to(beNil())
                    }
                    expect(Array(receivedArticles)).to(equal(expectedArticles))
                }

                it("does not ask the local feed service to try again") {
                    expect(localFeedService.articlesOfFeedCalls).to(equal([feed]))
                }

                it("returns the same subscription if you ask for this information twice") {
                    expect(subject.articles(of: feed)).to(beIdenticalTo(subscription))
                    expect(subject.articles(of: feedFactory(title: "other feed"))).toNot(beIdenticalTo(subscription))
                }

                it("asks the network feed service for articles of the feed") {
                    expect(networkFeedService.articlesOfFeedCalls).to(equal([feed]))
                }

                context("when the network feed service succeeds") {
                    let networkArticles = [articleFactory(title: "article 3"), articleFactory(title: "article 4")]

                    beforeEach {
                        networkFeedService.articlesOfFeedPromises.last?.resolve(.success(AnyCollection(networkArticles)))
                    }

                    it("updates the subscription with the list of feeds") {
                        expect(subscription.isFinished).to(beFalse())
                        expect(subscription.value).toNot(beNil())
                        guard let receivedArticles = subscription.value?.value else {
                            return expect(subscription.value?.error).to(beNil())
                        }
                        expect(Array(receivedArticles)).to(equal(networkArticles))
                    }

                    it("does not try to fetch articles again") {
                        expect(localFeedService.articlesOfFeedCalls).to(equal([feed]))
                        expect(networkFeedService.articlesOfFeedCalls).to(equal([feed]))
                    }

                    it("tells the local feed service to update") {
                        expect(localFeedService.updateArticlesCalls).to(haveCount(1))
                        guard let updateArticlesCall = localFeedService.updateArticlesCalls.last else { return }
                        expect(Array(updateArticlesCall.articles)).to(equal(networkArticles))
                        expect(updateArticlesCall.feed).to(equal(feed))
                    }

                    it("returns the same subscription if you ask for this information twice") {
                        expect(subject.articles(of: feed)).to(beIdenticalTo(subscription))
                        expect(subject.articles(of: feedFactory(title: "other feed"))).toNot(beIdenticalTo(subscription))
                    }

                    context("when the local feed service updates") {
                        let savedArticles = [articleFactory(title: "article 5"), articleFactory(title: "article 6")]

                        beforeEach {
                            localFeedService.updateArticlesPromises.last?.resolve(.success(AnyCollection(savedArticles)))
                        }

                        it("finishes the subscription with the newly saved articles") {
                            expect(subscription.isFinished).to(beTrue())
                            expect(subscription.value).toNot(beNil())
                            guard let receivedArticles = subscription.value?.value else {
                                return expect(subscription.value?.error).to(beNil())
                            }
                            expect(Array(receivedArticles)).to(equal(savedArticles))
                        }

                        it("returns a new subscription if you ask again") {
                            expect(subject.articles(of: feed)).toNot(beIdenticalTo(subscription))
                        }

                        it("returns a new subscription if you ask for this information twice") {
                            expect(subject.articles(of: feed)).toNot(beIdenticalTo(subscription))
                        }
                    }

                    context("when the local feed service fails") {
                        beforeEach {
                            localFeedService.updateArticlesPromises.last?.resolve(.failure(.database(.entryNotFound)))
                        }

                        it("finishes the subscription without updating it") {
                            expect(subscription.isFinished).to(beTrue())
                            expect(subscription.value).toNot(beNil())
                            guard let receivedArticles = subscription.value?.value else {
                                return expect(subscription.value?.error).to(beNil())
                            }
                            expect(Array(receivedArticles)).to(equal(networkArticles))
                        }

                        it("returns a new subscription if you ask again") {
                            expect(subject.articles(of: feed)).toNot(beIdenticalTo(subscription))
                        }

                        it("returns a new subscription if you ask for this information twice") {
                            expect(subject.articles(of: feed)).toNot(beIdenticalTo(subscription))
                        }
                    }
                }

                context("when the network feed service fails") {
                    beforeEach {
                        networkFeedService.articlesOfFeedPromises.last?.resolve(.failure(.unknown))
                    }

                    it("finishes the subscription without updating it") {
                        expect(subscription.isFinished).to(beTrue())
                        expect(subscription.value).toNot(beNil())
                        guard let receivedArticles = subscription.value?.value else {
                            return expect(subscription.value?.error).to(beNil())
                        }
                        expect(Array(receivedArticles)).to(equal(expectedArticles))
                    }

                    it("does not tell the local feed service to update") {
                        expect(localFeedService.updateArticlesCalls).to(beEmpty())
                    }

                    it("returns a new subscription if you ask again") {
                        expect(subject.articles(of: feed)).toNot(beIdenticalTo(subscription))
                    }
                }
            }

            context("when the local feed service fails") {
                beforeEach {
                    localFeedService.articlesOfFeedPromises.last?.resolve(.failure(.database(.entryNotFound)))
                }

                it("updates the subscription with the value") {
                    expect(subscription.value).toNot(beNil())
                    expect(subscription.value?.error).to(equal(.database(.entryNotFound)))
                    expect(subscription.isFinished).to(beFalse())
                }

                it("does not ask the local feed service to try again") {
                    expect(localFeedService.articlesOfFeedCalls).to(equal([feed]))
                }

                it("returns the same subscription if you ask for this information twice") {
                    expect(subject.articles(of: feed)).to(beIdenticalTo(subscription))
                    expect(subject.articles(of: feedFactory(title: "other feed"))).toNot(beIdenticalTo(subscription))
                }

                it("asks the network feed service for articles of the feed") {
                    expect(networkFeedService.articlesOfFeedCalls).to(equal([feed]))
                }

                context("when the network feed service succeeds") {
                    let networkArticles = [articleFactory(title: "article 3"), articleFactory(title: "article 4")]

                    beforeEach {
                        networkFeedService.articlesOfFeedPromises.last?.resolve(.success(AnyCollection(networkArticles)))
                    }

                    it("updates the subscription with the list of feeds") {
                        expect(subscription.isFinished).to(beFalse())
                        expect(subscription.value).toNot(beNil())
                        guard let receivedArticles = subscription.value?.value else {
                            return expect(subscription.value?.error).to(beNil())
                        }
                        expect(Array(receivedArticles)).to(equal(networkArticles))
                    }

                    it("does not try to fetch articles again") {
                        expect(localFeedService.articlesOfFeedCalls).to(equal([feed]))
                        expect(networkFeedService.articlesOfFeedCalls).to(equal([feed]))
                    }

                    it("tells the local feed service to update") {
                        expect(localFeedService.updateArticlesCalls).to(haveCount(1))
                        guard let updateArticlesCall = localFeedService.updateArticlesCalls.last else { return }
                        expect(Array(updateArticlesCall.articles)).to(equal(networkArticles))
                        expect(updateArticlesCall.feed).to(equal(feed))
                    }

                    it("returns the same subscription if you ask for this information twice") {
                        expect(subject.articles(of: feed)).to(beIdenticalTo(subscription))
                        expect(subject.articles(of: feedFactory(title: "other feed"))).toNot(beIdenticalTo(subscription))
                    }

                    context("when the local feed service updates") {
                        let savedArticles = [articleFactory(title: "article 5"), articleFactory(title: "article 6")]

                        beforeEach {
                            localFeedService.updateArticlesPromises.last?.resolve(.success(AnyCollection(savedArticles)))
                        }

                        it("finishes the subscription with the newly saved articles") {
                            expect(subscription.isFinished).to(beTrue())
                            expect(subscription.value).toNot(beNil())
                            guard let receivedArticles = subscription.value?.value else {
                                return expect(subscription.value?.error).to(beNil())
                            }
                            expect(Array(receivedArticles)).to(equal(savedArticles))
                        }

                        it("returns a new subscription if you ask again") {
                            expect(subject.articles(of: feed)).toNot(beIdenticalTo(subscription))
                        }

                        it("returns a new subscription if you ask for this information twice") {
                            expect(subject.articles(of: feed)).toNot(beIdenticalTo(subscription))
                        }
                    }

                    context("when the local feed service fails") {
                        beforeEach {
                            localFeedService.updateArticlesPromises.last?.resolve(.failure(.database(.entryNotFound)))
                        }

                        it("finishes the subscription without updating it") {
                            expect(subscription.isFinished).to(beTrue())
                            expect(subscription.value).toNot(beNil())
                            guard let receivedArticles = subscription.value?.value else {
                                return expect(subscription.value?.error).to(beNil())
                            }
                            expect(Array(receivedArticles)).to(equal(networkArticles))
                        }

                        it("returns a new subscription if you ask again") {
                            expect(subject.articles(of: feed)).toNot(beIdenticalTo(subscription))
                        }

                        it("returns a new subscription if you ask for this information twice") {
                            expect(subject.articles(of: feed)).toNot(beIdenticalTo(subscription))
                        }
                    }
                }

                context("when the network feed service fails") {
                    beforeEach {
                        networkFeedService.articlesOfFeedPromises.last?.resolve(.failure(.unknown))
                    }

                    it("finishes the subscription with the new error") {
                        expect(subscription.isFinished).to(beTrue())
                        expect(subscription.value).toNot(beNil())
                        expect(subscription.value?.error).to(equal(.unknown))
                    }

                    it("does not tell the local feed service to update") {
                        expect(localFeedService.updateArticlesCalls).to(beEmpty())
                    }

                    it("returns a new subscription if you ask again") {
                        expect(subject.articles(of: feed)).toNot(beIdenticalTo(subscription))
                    }
                }
            }
        }

        describe("subcribe(to:)") {
            var future: Future<Result<Feed, TethysError>>!
            let url = URL(string: "https://example.com/feed1")!

            beforeEach {
                future = subject.subscribe(to: url)
            }

            it("asks both feed services to subscribe to the url at the same time") {
                expect(localFeedService.subscribeCalls).to(equal([url]))
                expect(networkFeedService.subscribeCalls).to(equal([url]))
            }

            describe("when both succeed") {
                context("with similar feed objects") {
                    let feed1 = feedFactory(title: "feed1")
                    let feed2 = feedFactory(title: "feed1")

                    beforeEach {
                        localFeedService.subscribePromises.last?.resolve(.success(feed1))
                        networkFeedService.subscribePromises.last?.resolve(.success(feed2))
                    }

                    it("resolves the future with one of them") {
                        expect(future).to(beResolved())
                        expect(future.value?.value).to(equal(feed1))
                    }
                }

                context("with different feed objects") {
                    let feed1 = feedFactory(title: "feed1")
                    let feed2 = feedFactory(title: "feed2")

                    beforeEach {
                        localFeedService.subscribePromises.last?.resolve(.success(feed1))
                        networkFeedService.subscribePromises.last?.resolve(.success(feed2))
                    }

                    it("does not yet resolve the future") {
                        expect(future).toNot(beResolved())
                    }

                    it("tells the local feed service to update the feed with the network feed services' feed") {
                        expect(localFeedService.updateFeedFromCalls).to(equal([feed2]))
                    }

                    describe("when the update feed call succeeds") {
                        let updatedFeed = feedFactory(title: "feed3")

                        beforeEach {
                            localFeedService.updateFeedFromPromises.last?.resolve(.success(updatedFeed))
                        }

                        it("resolves the future with the updated feed") {
                            expect(future).to(beResolved())
                            expect(future.value?.value).to(equal(updatedFeed))
                        }
                    }

                    describe("when the update feed call fails") {
                        beforeEach {
                            localFeedService.updateFeedFromPromises.last?.resolve(.failure(.database(.entryNotFound)))
                        }

                        it("resolves the future with the network service' feed") {
                            expect(future).to(beResolved())
                            expect(future.value?.value).to(equal(feed2))
                        }
                    }
                }
            }

            describe("when the local subscription succeeds but the network subscription request fails") {
                let feed = feedFactory()
                beforeEach {
                    localFeedService.subscribePromises.last?.resolve(.success(feed))
                    networkFeedService.subscribePromises.last?.resolve(.failure(.network(url, .internetDown)))
                }

                it("resolves the future successfully, hiding the error") {
                    expect(future).to(beResolved())
                    expect(future.value?.value).to(equal(feed))
                }
            }

            describe("when the local subscription request fails but the network request succeeds") {
                let feed = feedFactory()
                beforeEach {
                    localFeedService.subscribePromises.last?.resolve(.failure(.database(.unknown)))
                    networkFeedService.subscribePromises.last?.resolve(.success(feed))
                }

                it("does not yet resolve the future") {
                    expect(future).toNot(beResolved())
                }

                it("tells the local feed service to update the feed with the network feed services' feed") {
                    expect(localFeedService.updateFeedFromCalls).to(equal([feed]))
                }

                describe("when the update feed call succeeds") {
                    let updatedFeed = feedFactory(title: "feed3")

                    beforeEach {
                        localFeedService.updateFeedFromPromises.last?.resolve(.success(updatedFeed))
                    }

                    it("resolves the future with the updated feed") {
                        expect(future).to(beResolved())
                        expect(future.value?.value).to(equal(updatedFeed))
                    }
                }

                describe("when the update feed call fails") {
                    beforeEach {
                        localFeedService.updateFeedFromPromises.last?.resolve(.failure(.database(.entryNotFound)))
                    }

                    it("resolves the future with the network service' feed") {
                        expect(future).to(beResolved())
                        expect(future.value?.value).to(equal(feed))
                    }
                }
            }

            describe("when both fail") {
                beforeEach {
                    localFeedService.subscribePromises.last?.resolve(.failure(.database(.unknown)))
                    networkFeedService.subscribePromises.last?.resolve(.failure(.network(url, .internetDown)))
                }

                it("resolves the future with the combined failure") {
                    expect(future).to(beResolved())
                    expect(future.value?.error).to(equal(.multiple([
                        .database(.unknown),
                        .network(url, .internetDown)
                    ])))
                }
            }
        }

        describe("unsubscribe(from:)") {
            var future: Future<Result<Void, TethysError>>!
            let feed = feedFactory()

            let unsubscribeURL = URL(string: "https://example.com/unsubscribe")!

            beforeEach {
                future = subject.unsubscribe(from: feed)
            }

            it("asks both feed services to unsubscribe from the feed at the same time") {
                expect(localFeedService.removeFeedCalls).to(equal([feed]))
                expect(networkFeedService.removeFeedCalls).to(equal([feed]))
            }

            describe("when both feed services succeed") {
                beforeEach {
                    localFeedService.removeFeedPromises.last?.resolve(.success(Void()))
                    networkFeedService.removeFeedPromises.last?.resolve(.success(Void()))
                }

                it("resolves the future successfully") {
                    expect(future).to(beResolved())
                    expect(future.value?.value).to(beVoid())
                }
            }

            describe("when the local feed service succeeds but the network feed service fails") {
                beforeEach {
                    localFeedService.removeFeedPromises.last?.resolve(.success(Void()))
                    networkFeedService.removeFeedPromises.last?.resolve(.failure(.network(unsubscribeURL, .badResponse)))
                }

                it("resolves the future with the local feed service's error") {
                    expect(future).to(beResolved())
                    expect(future.value?.error).to(equal(.network(unsubscribeURL, .badResponse)))
                }
            }

            describe("when the local feed service fails but the network feed service succeeds") {
                beforeEach {
                    localFeedService.removeFeedPromises.last?.resolve(.failure(.database(.notFound)))
                    networkFeedService.removeFeedPromises.last?.resolve(.success(Void()))
                }

                it("resolves the future with the local feed service's error") {
                    expect(future).to(beResolved())
                    expect(future.value?.error).to(equal(.database(.notFound)))
                }
            }

            describe("when both feed services fail") {
                beforeEach {
                    localFeedService.removeFeedPromises.last?.resolve(.failure(.database(.entryNotFound)))
                    networkFeedService.removeFeedPromises.last?.resolve(.failure(.network(unsubscribeURL, .internetDown)))
                }

                it("resolves the future with both errors") {
                    expect(future).to(beResolved())
                    expect(future.value?.error).to(equal(.multiple([
                        .database(.entryNotFound),
                        .network(unsubscribeURL, .internetDown)
                    ])))
                }
            }
        }

        describe("readAll(of:)") {
            var future: Future<Result<Void, TethysError>>!
            let feed = feedFactory(unreadCount: 20)

            let readAllURL = URL(string: "https://example.com/readAll")!

            beforeEach {
                future = subject.readAll(of: feed)
            }

            it("sets the feed's unread count to 0") {
                expect(feed.unreadCount).to(equal(0))
            }

            it("asks both feed services to mark all articles for that feed as read") {
                expect(localFeedService.readAllOfFeedCalls).to(equal([feed]))
                expect(networkFeedService.readAllOfFeedCalls).to(equal([feed]))
            }

            describe("when both feed services succeed") {
                beforeEach {
                    localFeedService.readAllOfFeedPromises.last?.resolve(.success(Void()))
                    networkFeedService.readAllOfFeedPromises.last?.resolve(.success(Void()))
                }

                it("resolves the future successfully") {
                    expect(future).to(beResolved())
                    expect(future.value?.value).to(beVoid())
                }
            }

            describe("when the local feed service succeeds, but the network service fails") {
                beforeEach {
                    localFeedService.readAllOfFeedPromises.last?.resolve(.success(Void()))
                    networkFeedService.readAllOfFeedPromises.last?.resolve(.failure(.network(readAllURL, .dns)))
                }

                it("resolves the future successfully") {
                    expect(future).to(beResolved())
                    expect(future.value?.value).to(beVoid())
                }
            }

            describe("when the local feed service fails, and the network service succeeds") {
                beforeEach {
                    networkFeedService.readAllOfFeedPromises.last?.resolve(.success(Void()))
                    localFeedService.readAllOfFeedPromises.last?.resolve(.failure(.database(.entryNotFound)))
                }

                it("resolves the future successfully") {
                    expect(future).to(beResolved())
                    expect(future.value?.value).to(beVoid())
                }
            }

            describe("when both feed services fail") {
                beforeEach {
                    localFeedService.readAllOfFeedPromises.last?.resolve(.failure(.database(.entryNotFound)))
                    networkFeedService.readAllOfFeedPromises.last?.resolve(.failure(.network(readAllURL, .dns)))
                }

                it("resolves the future with both failures") {
                    expect(future).to(beResolved())
                    expect(future.value?.error).to(equal(.multiple([
                        .database(.entryNotFound),
                        .network(readAllURL, .dns)
                    ])))
                }
            }
        }
    }
}
