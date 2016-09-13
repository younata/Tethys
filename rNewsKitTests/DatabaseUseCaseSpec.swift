import Quick
import Nimble
import CBGPromise
import Result
@testable import rNewsKit

class DatabaseUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: FakeDatabaseUseCase!
        let feeds = [
            Feed(title: "1", url: URL(string: "https://example.com/1")!, summary: "", tags: ["a", "b", "c", "d"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
            Feed(title: "2", url: URL(string: "https://example.com/2")!, summary: "", tags: ["b", "d"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
            Feed(title: "3", url: URL(string: "https://example.com/3")!, summary: "", tags: ["dad"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
            Feed(title: "4", url: URL(string: "https://example.com/4")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
        ]

        beforeEach {
            subject = FakeDatabaseUseCase()
        }

        describe("feedsMatchingTag:") {
            var feedsTagPromise: Future<Result<[Feed], RNewsError>>? = nil

            context("without a tag") {
                context("when a nil tag is given") {
                    beforeEach {
                        feedsTagPromise = subject.feeds(matchingTag: nil)
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

                        feedsPromise.resolve(.success(feeds))

                        if let calledResults = feedsTagPromise?.value {
                            switch calledResults {
                            case let .success(receivedFeeds):
                                expect(receivedFeeds) == feeds
                            case .failure(_):
                                expect(false) == true
                            }
                        } else {
                            expect(false) == true
                        }
                    }

                    it("forwards the error when the feeds promise errors") {
                        guard let feedsPromise = subject.feedsPromises.first else { return }

                        feedsPromise.resolve(.failure(.unknown))

                        if let calledResults = feedsTagPromise?.value {
                            switch calledResults {
                            case .success(_):
                                expect(false) == true
                            case let .failure(error):
                                expect(error) == RNewsError.unknown
                            }
                        } else {
                            expect(false) == true
                        }
                    }
                }

                context("when an empty string is given") {
                    beforeEach {
                        feedsTagPromise = subject.feeds(matchingTag: "")
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

                        feedsPromise.resolve(.success(feeds))

                        if let calledResults = feedsTagPromise?.value {
                            switch calledResults {
                            case let .success(receivedFeeds):
                                expect(receivedFeeds) == feeds
                            case .failure(_):
                                expect(false) == true
                            }
                        } else {
                            expect(false) == true
                        }
                    }

                    it("forwards the error when the feeds promise errors") {
                        guard let feedsPromise = subject.feedsPromises.first else { return }

                        feedsPromise.resolve(.failure(.unknown))

                        if let calledResults = feedsTagPromise?.value {
                            switch calledResults {
                            case .success(_):
                                expect(false) == true
                            case let .failure(error):
                                expect(error) == RNewsError.unknown
                            }
                        } else {
                            expect(false) == true
                        }
                    }
                }
            }

            context("with a tag") {
                beforeEach {
                    feedsTagPromise = subject.feeds(matchingTag: "a")
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

                    feedsPromise.resolve(.success(feeds))

                    if let calledResults = feedsTagPromise?.value {
                        switch calledResults {
                        case let .success(receivedFeeds):
                            expect(receivedFeeds) == [feeds[0], feeds[2]]
                        case .failure(_):
                            expect(false) == true
                        }
                    } else {
                        expect(false) == true
                    }
                }

                it("forwards the error when the feeds promise errors") {
                    guard let feedsPromise = subject.feedsPromises.first else { return }

                    feedsPromise.resolve(.failure(.unknown))

                    if let calledResults = feedsTagPromise?.value {
                        switch calledResults {
                        case .success(_):
                            expect(false) == true
                        case let .failure(error):
                            expect(error) == RNewsError.unknown
                        }
                    } else {
                        expect(false) == true
                    }
                }
            }
        }
    }
}
