import Quick
import Nimble
import CBGPromise
import rNewsKit

class FutureOperationSpec: QuickSpec {
    override func spec() {
        var subject: FutureOperation!
        var kvoMonitor: KVOMonitor!

        var promise: Promise<Void>!
        var blockCallCount = 0

        beforeEach {
            blockCallCount = 0
            promise = Promise<Void>()

            subject = FutureOperation {
                blockCallCount += 1
                return promise.future
            }

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

        it("does not call the block") {
            expect(blockCallCount) == 0
        }

        describe("starting it") {
            beforeEach {
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

            describe("when the promise resolves") {
                beforeEach {
                    promise.resolve()
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
