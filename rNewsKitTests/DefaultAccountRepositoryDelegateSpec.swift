import Quick
import Nimble
@testable import rNewsKit
import Sinope
import CBGPromise
import Result

class DefaultAccountRepositoryDelegateSpec: QuickSpec {
    override func spec() {
        var subject: DefaultAccountRepositoryDelegate!
        var databaseUseCase: FakeDatabaseUseCase!
        var mainQueue: FakeOperationQueue!

        beforeEach {
            databaseUseCase = FakeDatabaseUseCase()
            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            subject = DefaultAccountRepositoryDelegate(databaseUseCase: databaseUseCase, mainQueue: mainQueue)
        }

        describe("accountRepositoryDidLogIn:") {
            var accountRepository: FakeAccountRepository!
            var sinopeRepository: FakeSinopeRepository!

            beforeEach {
                accountRepository = FakeAccountRepository()
                sinopeRepository = FakeSinopeRepository()
                accountRepository.backendRepositoryReturns(sinopeRepository)

                subject.accountRepositoryDidLogIn(accountRepository)
            }

            it("makes a request for the feeds") {
                expect(databaseUseCase.feedsPromises.count) == 1
            }

            describe("when the request comes back successfully") {
                var subscribePromise: Promise<Result<[NSURL], SinopeError>>!
                beforeEach {
                    subscribePromise = Promise<Result<[NSURL], SinopeError>>()
                    sinopeRepository.subscribeReturns(subscribePromise.future)

                    let feed = Feed(title: "title", url: NSURL(string: "https://example.com"), summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feed2 = Feed(title: "title", url: nil, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                    databaseUseCase.feedsPromises.last?.resolve(.Success([feed, feed2]))
                }

                it("tells the sinope repository to subscribe to feeds with urls") {
                    expect(sinopeRepository.subscribeCallCount) == 1
                    guard sinopeRepository.subscribeCallCount == 1 else { return }
                    let args = sinopeRepository.subscribeArgsForCall(0)
                    expect(args) == [NSURL(string: "https://example.com")!]
                }

                describe("when the subscribe request succeeds") {
                    beforeEach {
                        subscribePromise.resolve(.Success([]))
                    }

                    it("asks the databaseusecase to update its feeds") {
                        expect(databaseUseCase.didUpdateFeeds) == true
                    }
                }

                describe("when the subscribe request fails") {
                    beforeEach {
                        subscribePromise.resolve(.Failure(.Unknown))
                    }
                    it("does not the databaseusecase to update its feeds") {
                        expect(databaseUseCase.didUpdateFeeds) == false
                    }
                }
            }

            describe("when the request fails") {
                beforeEach {
                    databaseUseCase.feedsPromises.last?.resolve(.Failure(.Unknown))
                }

                it("does not tell the sinope repository to subscribe to feeds with urls") {
                    expect(sinopeRepository.subscribeCallCount) == 0
                }
            }
        }
    }
}
