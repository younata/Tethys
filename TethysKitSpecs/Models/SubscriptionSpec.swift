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
            var received: [SubscriptionUpdate<Int>] = []

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

            it("has a value of nil") {
                expect(subject.subscription.value).to(beNil())
            }

            describe("when updated") {
                beforeEach {
                    subject.update(with: 20)
                }

                it("calls the callbacks") {
                    expect(received).to(equal([.update(20)]))
                }

                it("immediately calls any additional callbacks that might be added") {
                    var moreReceived = [SubscriptionUpdate<Int>]()

                    subject.subscription.then { moreReceived.append($0) }

                    expect(moreReceived).to(equal([.update(20)]))
                }

                it("sets the subscription's value") {
                    expect(subject.subscription.value).to(equal(20))
                }

                describe("making more updates") {
                    beforeEach {
                        subject.update(with: 30)
                    }

                    it("calls the callbacks") {
                        expect(received).to(equal([.update(20), .update(30)]))
                    }

                    it("updates the subscription's value") {
                        expect(subject.subscription.value).to(equal(30))
                    }

                    it("additional callbacks now only received the latest value") {
                        var moreReceived = [SubscriptionUpdate<Int>]()

                        subject.subscription.then { moreReceived.append($0) }

                        expect(moreReceived).to(equal([.update(30)]))
                    }
                }

                describe("when finished") {
                    beforeEach {
                        subject.finish()
                    }

                    it("makes one last call, notifying the user that the subscription has petered out") {
                        expect(received).to(equal([.update(20), .finished]))
                    }

                    it("stops holding on to the callback blocks") {
                        expect(observer.count).to(equal(1), description: "Expected the block to have been deallocated")
                    }

                    it("notes to those who ask that it's finished") {
                        expect(subject.subscription.isFinished).to(beTrue())
                        expect(subject.isFinished).to(beTrue())
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
