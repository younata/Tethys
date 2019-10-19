import Quick
import Nimble
@testable import TethysKit

final class SubscriptionSpec: QuickSpec {
    override func spec() {
        var subject: Publisher<Int>!

        beforeEach {
            subject = Publisher<Int>()
        }

        describe("-then(:)") {
            var received: [Int] = []

            var observer: Observer!

            beforeEach {
                received = []

                observer = Observer()
                let memoryManagementReactor = IncrementOnDealloc(observed: observer)

                subject.subscription.then {
                    memoryManagementReactor.doSomething()
                    received.append($0)
                }
            }

            it("it does not call the callbacks") {
                expect(received).to(beEmpty())
            }

            describe("when updated") {
                beforeEach {
                    subject.update(with: 20)
                }

                it("calls the callbacks") {
                    expect(received).to(equal([20]))
                }

                it("immediately calls any additional callbacks that might be added") {
                    var moreReceived = [Int]()

                    subject.subscription.then { moreReceived.append($0) }

                    expect(moreReceived).to(equal([20]))
                }

                describe("making more updates") {
                    beforeEach {
                        subject.update(with: 30)
                    }

                    it("calls the callbacks") {
                        expect(received).to(equal([20, 30]))
                    }

                    it("additional callbacks now only received the latest value") {
                        var moreReceived = [Int]()

                        subject.subscription.then { moreReceived.append($0) }

                        expect(moreReceived).to(equal([30]))
                    }
                }

                describe("when finished") {
                    beforeEach {
                        subject.finish()
                    }

                    it("stops holding on to the callback blocks") {
                        expect(observer.count).to(equal(1), description: "Expected the block to have been deallocated")
                    }
                }
            }
        }
    }
}

private class Observer {
    private(set) var count = 0

    init() {}

    func observe() {
        count += 1
    }
}

private class IncrementOnDealloc {
    private let observed: Observer

    init(observed: Observer) {
        self.observed = observed
    }

    func doSomething() {
    }

    deinit {
        self.observed.observe()
    }
}
