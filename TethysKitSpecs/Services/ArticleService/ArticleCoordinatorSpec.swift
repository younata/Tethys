import Quick
import Nimble
import Result
import CBGPromise

@testable import TethysKit

final class ArticleCoordinatorSpec: QuickSpec {
    override func spec() {
        var subject: ArticleCoordinator!

        var localArticleService: FakeArticleService!
        var networkArticleService: FakeArticleService!

        beforeEach {
            localArticleService = FakeArticleService()
            networkArticleService = FakeArticleService()

            subject = ArticleCoordinator(
                localArticleService: localArticleService,
                networkArticleServiceProvider: { networkArticleService }
            )
        }

        describe("-mark(article:asRead:)") {
            var subscription: Subscription<Result<Article, TethysError>>!

            let article = articleFactory()

            beforeEach {
                subscription = subject.mark(article: article, asRead: true)
            }

            it("asks both the network article service and the local article service at the same time") {
                expect(localArticleService.markArticleAsReadCalls).to(haveCount(1))
                expect(networkArticleService.markArticleAsReadCalls).to(haveCount(1))
            }

            it("returns the same subscription if you ask this twice in a row") {
                expect(subject.mark(article: article, asRead: true)).to(beIdenticalTo(subscription))
                expect(subject.mark(article: article, asRead: false)).toNot(beIdenticalTo(subscription))
                expect(subject.mark(article: articleFactory(identifier: "other article"), asRead: true)).toNot(beIdenticalTo(subscription))
            }

            context("if the local article service succeeds") {
                let locallyUpdatedArticle = articleFactory()

                beforeEach {
                    localArticleService.markArticleAsReadPromises.last?.resolve(.success(locallyUpdatedArticle))
                }

                it("updates the subscription with the updated article") {
                    expect(subscription.value).toNot(beNil())
                    expect(subscription.value?.value).to(equal(locallyUpdatedArticle))
                    expect(subscription.isFinished).to(beFalse())
                }

                it("still returns the same subscription if you ask this twice in a row") {
                    expect(subject.mark(article: article, asRead: true)).to(beIdenticalTo(subscription))
                    expect(subject.mark(article: article, asRead: false)).toNot(beIdenticalTo(subscription))
                    expect(subject.mark(article: articleFactory(identifier: "other article"), asRead: true)).toNot(beIdenticalTo(subscription))
                }

                context("if the network article service succeeds") {
                    let networkUpdatedArticle = articleFactory()

                    beforeEach {
                        networkArticleService.markArticleAsReadPromises.last?.resolve(.success(networkUpdatedArticle))
                    }

                    it("finishes the subscription without updating it") {
                        expect(subscription.value).toNot(beNil())
                        expect(subscription.value?.value).to(equal(locallyUpdatedArticle))
                        expect(subscription.isFinished).to(beTrue())
                    }

                    it("returns a new subscription if you try this again") {
                        expect(subject.mark(article: article, asRead: true)).toNot(beIdenticalTo(subscription))
                    }
                }

                context("if the network article service fails") {
                    beforeEach {
                        networkArticleService.markArticleAsReadPromises.last?.resolve(.failure(.unknown))
                    }

                    it("updates the subscription with the error and it finishes it") {
                        expect(subscription.value).toNot(beNil())
                        expect(subscription.value?.error).to(equal(.unknown))
                        expect(subscription.isFinished).to(beTrue())
                    }

                    it("returns a new subscription if you try this again") {
                        expect(subject.mark(article: article, asRead: true)).toNot(beIdenticalTo(subscription))
                    }
                }
            }

            describe("when the local article service fails") {
                beforeEach {
                    localArticleService.markArticleAsReadPromises.last?.resolve(.failure(.database(.entryNotFound)))
                }

                it("updates the subscription with the error") {
                    expect(subscription.value).toNot(beNil())
                    expect(subscription.value?.error).to(equal(.database(.entryNotFound)))
                    expect(subscription.isFinished).to(beFalse())
                }

                it("still returns the same subscription if you ask this twice in a row") {
                    expect(subject.mark(article: article, asRead: true)).to(beIdenticalTo(subscription))
                    expect(subject.mark(article: article, asRead: false)).toNot(beIdenticalTo(subscription))
                    expect(subject.mark(article: articleFactory(identifier: "other article"), asRead: true)).toNot(beIdenticalTo(subscription))
                }

                context("if the network article service succeeds") {
                    let networkUpdatedArticle = articleFactory()

                    beforeEach {
                        networkArticleService.markArticleAsReadPromises.last?.resolve(.success(networkUpdatedArticle))
                    }

                    it("updates the subscription with the article and finishes it") {
                        expect(subscription.value).toNot(beNil())
                        expect(subscription.value?.value).to(equal(networkUpdatedArticle))
                        expect(subscription.isFinished).to(beTrue())
                    }

                    it("returns a new subscription if you try this again") {
                        expect(subject.mark(article: article, asRead: true)).toNot(beIdenticalTo(subscription))
                    }
                }

                context("if the network article service fails") {
                    beforeEach {
                        networkArticleService.markArticleAsReadPromises.last?.resolve(.failure(.unknown))
                    }

                    it("updates the subscription with the error and it finishes it") {
                        expect(subscription.value).toNot(beNil())
                        expect(subscription.value?.error).to(equal(.unknown))
                        expect(subscription.isFinished).to(beTrue())
                    }

                    it("returns a new subscription if you try this again") {
                        expect(subject.mark(article: article, asRead: true)).toNot(beIdenticalTo(subscription))
                    }
                }
            }
        }

        describe("-remove(article:)") {
            var future: Future<Result<Void, TethysError>>!

            let article = articleFactory()

            beforeEach {
                future = subject.remove(article: article)
            }

            it("returns what the local article service says") {
                expect(localArticleService.removeArticleCalls).to(equal([article]))
                guard let removeArticlePromise = localArticleService.removeArticlePromises.last else {
                    return fail("No promises to remove article")
                }
                expect(future).to(beIdenticalTo(removeArticlePromise.future))
            }

            it("does not ask the network article service for help") {
                expect(networkArticleService.removeArticleCalls).to(haveCount(0))
            }
        }

        describe("-authors(of:)") {
            let article = articleFactory()

            it("returns what the local article service says without consulting the network") {
                localArticleService.authorStub = [article: "some person"]

                expect(subject.authors(of: article)).to(equal("some person"))
                expect(localArticleService.authorsCalls).to(equal([article]))
                expect(networkArticleService.authorsCalls).to(beEmpty())
            }
        }

        describe("date(for:)") {
            let article = articleFactory()

            it("returns what the local article service says without consulting the network") {
                localArticleService.dateForArticleStub = [article: Date(timeIntervalSince1970: 10000)]

                expect(subject.date(for: article)).to(equal(Date(timeIntervalSince1970: 10000)))
                expect(localArticleService.dateForArticleCalls).to(equal([article]))
                expect(networkArticleService.dateForArticleCalls).to(beEmpty())
            }
        }

        describe("estimatedReadingTime(of:)") {
            let article = articleFactory()

            it("returns what the local article service says without consulting the network") {
                localArticleService.estimatedReadingTimeStub = [article: 300]

                expect(subject.estimatedReadingTime(of: article)).to(equal(300))
                expect(localArticleService.estimatedReadingTimeCalls).to(equal([article]))
                expect(networkArticleService.estimatedReadingTimeCalls).to(beEmpty())
            }
        }
    }
}
