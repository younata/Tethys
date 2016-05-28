import Quick
import Nimble
import CBGPromise
import Result
@testable import rNewsKit

class DatabaseUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: FakeDatabaseUseCase!
        let feeds = [
            Feed(title: "1", url: nil, summary: "", query: nil, tags: ["a", "b", "c", "d"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
            Feed(title: "2", url: nil, summary: "", query: nil, tags: ["b", "d"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
            Feed(title: "3", url: nil, summary: "", query: nil, tags: ["dad"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
            Feed(title: "4", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
        ]

        beforeEach {
            subject = FakeDatabaseUseCase()
        }

        describe("feedsMatchingTag:") {
            var feedsTagPromise: Future<Result<[Feed], RNewsError>>? = nil

            context("without a tag") {
                context("when a nil tag is given") {
                    beforeEach {
                        feedsTagPromise = subject.feedsMatchingTag(nil)
                    }

                    it("returns an in-progress promise") {
                        expect(feedsTagPromise).toNot(beNil())
                        expect(feedsTagPromise?.value).to(beNil())
                    }

                    it("makes a call to the implemented feeds") {
                        expect(subject.feedsPromises.count) == 1
                    }

                    it("returns all the feeds when feeds promise returns successfully") {
                        guard let feedsPromise = subject.feedsPromises.first else { return }

                        feedsPromise.resolve(.Success(feeds))

                        if let calledResults = feedsTagPromise?.value {
                            switch calledResults {
                            case let .Success(receivedFeeds):
                                expect(receivedFeeds) == feeds
                            case .Failure(_):
                                expect(false) == true
                            }
                        } else {
                            expect(false) == true
                        }
                    }

                    it("forwards the error when the feeds promise errors") {
                        guard let feedsPromise = subject.feedsPromises.first else { return }

                        feedsPromise.resolve(.Failure(.Unknown))

                        if let calledResults = feedsTagPromise?.value {
                            switch calledResults {
                            case .Success(_):
                                expect(false) == true
                            case let .Failure(error):
                                expect(error) == RNewsError.Unknown
                            }
                        } else {
                            expect(false) == true
                        }
                    }
                }

                context("when an empty string is given") {
                    beforeEach {
                        feedsTagPromise = subject.feedsMatchingTag("")
                    }

                    it("returns an in-progress promise") {
                        expect(feedsTagPromise).toNot(beNil())
                        expect(feedsTagPromise?.value).to(beNil())
                    }

                    it("makes a call to the implemented feeds") {
                        expect(subject.feedsPromises.count) == 1
                    }

                    it("returns all the feeds when feeds promise returns successfully") {
                        guard let feedsPromise = subject.feedsPromises.first else { return }

                        feedsPromise.resolve(.Success(feeds))

                        if let calledResults = feedsTagPromise?.value {
                            switch calledResults {
                            case let .Success(receivedFeeds):
                                expect(receivedFeeds) == feeds
                            case .Failure(_):
                                expect(false) == true
                            }
                        } else {
                            expect(false) == true
                        }
                    }

                    it("forwards the error when the feeds promise errors") {
                        guard let feedsPromise = subject.feedsPromises.first else { return }

                        feedsPromise.resolve(.Failure(.Unknown))

                        if let calledResults = feedsTagPromise?.value {
                            switch calledResults {
                            case .Success(_):
                                expect(false) == true
                            case let .Failure(error):
                                expect(error) == RNewsError.Unknown
                            }
                        } else {
                            expect(false) == true
                        }
                    }
                }
            }

            context("with a tag") {
                beforeEach {
                    feedsTagPromise = subject.feedsMatchingTag("a")
                }

                it("returns an in-progress promise") {
                    expect(feedsTagPromise).toNot(beNil())
                    expect(feedsTagPromise?.value).to(beNil())
                }

                it("makes a call to the implemented feeds") {
                    expect(subject.feedsPromises.count) == 1
                }

                it("returns all the feeds when feeds promise returns successfully") {
                    guard let feedsPromise = subject.feedsPromises.first else { return }

                    feedsPromise.resolve(.Success(feeds))

                    if let calledResults = feedsTagPromise?.value {
                        switch calledResults {
                        case let .Success(receivedFeeds):
                            expect(receivedFeeds) == [feeds[0], feeds[2]]
                        case .Failure(_):
                            expect(false) == true
                        }
                    } else {
                        expect(false) == true
                    }
                }

                it("forwards the error when the feeds promise errors") {
                    guard let feedsPromise = subject.feedsPromises.first else { return }

                    feedsPromise.resolve(.Failure(.Unknown))

                    if let calledResults = feedsTagPromise?.value {
                        switch calledResults {
                        case .Success(_):
                            expect(false) == true
                        case let .Failure(error):
                            expect(error) == RNewsError.Unknown
                        }
                    } else {
                        expect(false) == true
                    }
                }
            }
        }
    }
}