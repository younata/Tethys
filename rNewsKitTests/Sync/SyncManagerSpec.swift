import Quick
import Nimble
import CBGPromise
import Result
import Sinope
@testable import rNewsKit

class SyncManagerSpec: QuickSpec {
    override func spec() {
        var subject: SyncManager!

        var workQueue: FakeOperationQueue!
        var mainQueue: FakeOperationQueue!

        var dataService: InMemoryDataService!
        var repository: FakeSinopeRepository!
        var accountRepository: FakeAccountRepository!

        beforeEach {
            workQueue = FakeOperationQueue()
            mainQueue = FakeOperationQueue()

            let dataServiceFactory = FakeDataServiceFactory()
            dataService = InMemoryDataService(mainQueue: FakeOperationQueue(), searchIndex: nil)
            dataServiceFactory.currentDataService = dataService

            repository = FakeSinopeRepository()

            accountRepository = FakeAccountRepository()

            subject = SyncManager(workQueue: workQueue, mainQueue: mainQueue, dataServiceFactory: dataServiceFactory, accountRepository: accountRepository)
        }

        describe("update(article:)") {
            var article: rNewsKit.Article!

            beforeEach {
                article = Article(title: "title", link: URL(string: "https://example.com/1")!, summary: "summary",
                                  authors: [], published: Date(), updatedAt: nil, identifier: "id", content: "cont",
                                  read: false, synced: true, estimatedReadingTime: 0, feed: nil, flags: [])
            }

            context("when the user is not logged in") {
                beforeEach {
                    accountRepository.backendRepositoryReturns(nil)

                    subject.update(article: article)
                }

                it("does nothing") {
                    expect(workQueue.operationCount) == 0
                    expect(mainQueue.operationCount) == 0
                }
            }

            context("when the user is logged in") {
                beforeEach {
                    accountRepository.backendRepositoryReturns(repository)

                    subject.update(article: article)
                }

                it("adds two operations to the work queue") {
                    expect(workQueue.operationCount) == 2
                    expect(mainQueue.operationCount) == 0
                }

                it("first would run an UpdateArticleOperation at utility priority") {
                    expect(workQueue.internalOperations.first).to(beAKindOf(UpdateArticleOperation.self))

                    expect(workQueue.internalOperations.first?.qualityOfService) == .utility
                }

                it("second it would run a FutureOperation that depends on the first operation") {
                    expect(workQueue.internalOperations.last).to(beAKindOf(FutureOperation.self))

                    expect(workQueue.internalOperations.last?.dependencies.count) == 1
                    expect(workQueue.internalOperations.last?.dependencies.first) === workQueue.internalOperations.first
                }

                describe("after the first operation runs") {
                    beforeEach {
                        let markReadPromise = Promise<Result<Void, SinopeError>>()
                        repository.markReadReturns(markReadPromise.future)

                        markReadPromise.resolve(.success())

                        workQueue.runNextOperation()
                    }

                    it("does not add any further operations") {
                        expect(workQueue.operationCount) == 1
                        expect(mainQueue.operationCount) == 0
                    }

                    it("now would run a FutureOperation at utility priority") {
                        expect(workQueue.internalOperations.first).to(beAKindOf(FutureOperation.self))

                        expect(workQueue.internalOperations.first?.qualityOfService) == .utility
                    }

                    describe("when the second operation runs") {
                        beforeEach {
                            workQueue.runNextOperation()
                        }

                        it("does not add any further operations") {
                            expect(workQueue.operationCount) == 0
                            expect(mainQueue.operationCount) == 0
                        }

                        it("saves the article") {
                            expect(dataService.saveCallCount) == 1
                            let args = dataService.saveCallArgs.first

                            expect(args?.0.count) == 0
                            expect(args?.1.count) == 1

                            expect(args?.1.first) == article
                        }
                    }
                }
            }
        }
    }
}
