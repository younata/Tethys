import Quick
import Nimble
@testable import rNewsKit
import CBGPromise
import Result
import Sinope

class UpdateArticleOperationSpec: QuickSpec {
    override func spec() {
        var subject: UpdateArticleOperation!
        var backendRepository: FakeSinopeRepository!
        var kvoMonitor: KVOMonitor!

        var article: rNewsKit.Article!

        beforeEach {
            article = Article(title: "title", link: URL(string: "https://example.com/1")!, summary: "summary",
                              authors: [], published: Date(), updatedAt: nil, identifier: "id", content: "", read: false,
                              synced: true, estimatedReadingTime: 0, feed: nil, flags: [])
            backendRepository = FakeSinopeRepository()

            subject = UpdateArticleOperation(articles: [article], backendRepository: backendRepository)

            kvoMonitor = KVOMonitor()

            kvoMonitor.monitor(object: subject, keyPath: "isExecuting", changes: [.new])

            kvoMonitor.monitor(object: subject, keyPath: "isFinished", changes: [.new])
        }

        it("initially has an isExecuting value of false") {
            expect(subject.isExecuting) == false
        }

        it("initially has an isFinished value of false") {
            expect(subject.isFinished) == false
        }

        it("has an isAsynchronous value of true") {
            expect(subject.isAsynchronous) == true
        }

        describe("starting it") {
            var markReadPromise: Promise<Result<Void, SinopeError>>!

            beforeEach {
                markReadPromise = Promise<Result<Void, SinopeError>>()
                backendRepository.markReadReturns(markReadPromise.future)

                subject.start()
            }

            it("now has an isExecuting value of true") {
                expect(subject.isExecuting) == true
            }

            it("still has an isFinished value of false") {
                expect(subject.isFinished) == false
            }

            it("sends a KVO message for isExecuting") {
                let isExecutingMessages = kvoMonitor.receivedNotifications.filter { $0.sender as AnyObject === subject && $0.keyPath == "isExecuting" }
                expect(isExecutingMessages.count) == 1
                let message = isExecutingMessages.first
                expect(message?.change?[NSKeyValueChangeKey.newKey] as? Bool) == true
            }

            it("marks the article as unsynced") {
                expect(article.synced) == false
            }

            it("makes a request to the backend server marking the specified article as read") {
                expect(backendRepository.markReadCallCount) == 1

                guard backendRepository.markReadCallCount == 1 else { return }

                let args = backendRepository.markReadArgsForCall(0)
                expect(args) == [URL(string: "https://example.com/1")!: false]
            }

            context("when the call succeeds") {
                beforeEach {
                    markReadPromise.resolve(.success())
                }

                it("marks the article as synced") {
                    expect(article.synced) == true
                }

                it("now has an isExecuting value of false") {
                    expect(subject.isExecuting) == false
                }

                it("now has an isFinished value of true") {
                    expect(subject.isFinished) == true
                }

                it("sends a KVO message for isExecuting") {
                    let isExecutingMessages = kvoMonitor.receivedNotifications.filter { $0.sender as AnyObject === subject && $0.keyPath == "isExecuting" }
                    expect(isExecutingMessages.count) == 2
                    let message = isExecutingMessages.last
                    expect(message?.change?[NSKeyValueChangeKey.newKey] as? Bool) == false
                }

                it("sends a KVO message for isFinished") {
                    let isFinishedMessages = kvoMonitor.receivedNotifications.filter { $0.sender as AnyObject === subject && $0.keyPath == "isFinished" }
                    expect(isFinishedMessages.count) == 1
                    let message = isFinishedMessages.last
                    expect(message?.change?[NSKeyValueChangeKey.newKey] as? Bool) == true
                }
            }

            context("when the call fails") {
                beforeEach {
                    markReadPromise.resolve(.failure(.unknown))
                }

                it("marks the article as not synced") {
                    expect(article.synced) == false
                }

                it("now has an isExecuting value of false") {
                    expect(subject.isExecuting) == false
                }

                it("now has an isFinished value of true") {
                    expect(subject.isFinished) == true
                }

                it("sends a KVO message for isExecuting") {
                    let isExecutingMessages = kvoMonitor.receivedNotifications.filter { $0.sender as AnyObject === subject && $0.keyPath == "isExecuting" }
                    expect(isExecutingMessages.count) == 2
                    let message = isExecutingMessages.last
                    expect(message?.change?[NSKeyValueChangeKey.newKey] as? Bool) == false
                }

                it("sends a KVO message for isFinished") {
                    let isFinishedMessages = kvoMonitor.receivedNotifications.filter { $0.sender as AnyObject === subject && $0.keyPath == "isFinished" }
                    expect(isFinishedMessages.count) == 1
                    let message = isFinishedMessages.last
                    expect(message?.change?[NSKeyValueChangeKey.newKey] as? Bool) == true
                }
            }
        }
    }
}
