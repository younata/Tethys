import Quick
import Nimble
import CBGPromise
import Result
import Sinope
@testable import rNewsKit

class SyncManagerSpec: QuickSpec {
    override func spec() {
        var subject: SyncEngineManager!

        var workQueue: FakeOperationQueue!
        var mainQueue: FakeOperationQueue!

        var dataService: InMemoryDataService!
        var repository: FakeSinopeRepository!
        var accountRepository: FakeAccountRepository!

        var timerFactory: FakeTimerFactory!

        beforeEach {
            workQueue = FakeOperationQueue()
            mainQueue = FakeOperationQueue()

            let dataServiceFactory = FakeDataServiceFactory()
            dataService = InMemoryDataService(mainQueue: FakeOperationQueue(), searchIndex: nil)
            dataServiceFactory.currentDataService = dataService

            repository = FakeSinopeRepository()

            accountRepository = FakeAccountRepository()

            timerFactory = FakeTimerFactory()

            subject = SyncEngineManager(workQueue: workQueue, mainQueue: mainQueue, dataServiceFactory: dataServiceFactory, accountRepository: accountRepository, timerFactory: timerFactory)
        }

        describe("updateAllUnsyncedArticles()") {
            var article1: rNewsKit.Article!
            var article2: rNewsKit.Article!
            var article3: rNewsKit.Article!

            beforeEach {
                article1 = Article(title: "title1", link: URL(string: "https://example.com/1")!, summary: "summary",
                                   authors: [], published: Date(), updatedAt: nil, identifier: "id", content: "cont",
                                   read: false, synced: true, estimatedReadingTime: 0, feed: nil, flags: [])
                article2 = Article(title: "title2", link: URL(string: "https://example.com/2")!, summary: "summary",
                                   authors: [], published: Date(), updatedAt: nil, identifier: "id", content: "cont",
                                   read: true, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])
                article3 = Article(title: "title3", link: URL(string: "https://example.com/3")!, summary: "summary",
                                   authors: [], published: Date(), updatedAt: nil, identifier: "id", content: "cont",
                                   read: true, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])

                dataService.articles = [article1, article2, article3]
            }

            context("when the user is not logged in") {
                beforeEach {
                    accountRepository.backendRepositoryReturns(nil)

                    subject.updateAllUnsyncedArticles()
                }

                it("does nothing") {
                    expect(workQueue.operationCount) == 0
                    expect(mainQueue.operationCount) == 0
                }
            }

            context("when the user is logged in") {
                beforeEach {
                    accountRepository.backendRepositoryReturns(repository)

                    subject.updateAllUnsyncedArticles()
                }

                it("adds one operation to the work queue") {
                    expect(workQueue.operationCount) == 1
                    expect(mainQueue.operationCount) == 0
                }

                it("first would run a FutureOperation that runs at .utility priority") {
                    expect(workQueue.internalOperations.first).to(beAKindOf(FutureOperation.self))

                    expect(workQueue.internalOperations.first?.dependencies.count) == 0

                    expect(workQueue.internalOperations.first?.qualityOfService) == .utility
                }

                describe("when the first operation runs") {
                    context("and the dataService returns no articles") {
                        beforeEach {
                            dataService.articles = []

                            workQueue.runNextOperation()
                        }

                        it("adds NO operations to the work queue") {
                            expect(workQueue.operationCount) == 0
                            expect(mainQueue.operationCount) == 0
                        }
                    }

                    context("and the dataService returns some articles") {
                        beforeEach {
                            dataService.articles = [article1, article2, article3]

                            workQueue.runNextOperation()
                        }

                        it("adds two operations to the work queue") {
                            expect(workQueue.operationCount) == 2
                            expect(mainQueue.operationCount) == 0
                        }

                        it("first would run an UpdateArticleOperation at utility priority") {
                            expect(workQueue.internalOperations.first).to(beAKindOf(UpdateArticleOperation.self))

                            expect(workQueue.internalOperations.first?.qualityOfService) == .utility
                        }

                        it("uses the UpdateArticleOperation to update the article specified") {
                            guard let op = workQueue.internalOperations.first as? UpdateArticleOperation else {
                                fail("whoops")
                                return
                            }
                            expect(op.articles) == [article2, article3]
                        }

                        it("secondly it would run a FutureOperation that depends on the first operation") {
                            expect(workQueue.internalOperations.last).to(beAKindOf(FutureOperation.self))

                            expect(workQueue.internalOperations.last?.dependencies.count) == 1
                            expect(workQueue.internalOperations.last?.dependencies.first) === workQueue.internalOperations.first
                        }

                        describe("after the next operation runs successfully") {
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

                            describe("when the final operation runs") {
                                beforeEach {
                                    workQueue.runNextOperation()
                                }

                                it("does not add any further operations") {
                                    expect(workQueue.operationCount) == 0
                                    expect(mainQueue.operationCount) == 0
                                }

                                it("saves the articles") {
                                    expect(dataService.saveCallCount) == 1
                                    let args = dataService.saveCallArgs.first

                                    expect(args?.0.count) == 0
                                    expect(args?.1.count) == 2

                                    expect(args?.1) == [article2, article3]
                                }
                            }
                        }

                        describe("after the next operation runs, but fails") {
                            beforeEach {
                                let markReadPromise = Promise<Result<Void, SinopeError>>()
                                repository.markReadReturns(markReadPromise.future)

                                markReadPromise.resolve(.failure(.unknown))

                                workQueue.runNextOperation()
                            }

                            it("adds a timer to run this again") {
                                expect(timerFactory.nonrepeatingTimerCallCount) == 1

                                guard timerFactory.nonrepeatingTimerCallCount == 1 else { return }

                                let args = timerFactory.nonrepeatingTimerArgsForCall(0)

                                expect(args.0.timeIntervalSinceNow) ≈ 30 ± 1e-2
                                expect(args.1) ≈ 60
                            }

                            it("does not add any further operations") {
                                expect(workQueue.operationCount) == 1
                                expect(mainQueue.operationCount) == 0
                            }

                            it("now would run a FutureOperation at utility priority") {
                                expect(workQueue.internalOperations.first).to(beAKindOf(FutureOperation.self))

                                expect(workQueue.internalOperations.first?.qualityOfService) == .utility
                            }

                            describe("when the final operation runs") {
                                beforeEach {
                                    workQueue.runNextOperation()
                                }

                                it("does not add any further operations") {
                                    expect(workQueue.operationCount) == 0
                                    expect(mainQueue.operationCount) == 0
                                }

                                it("saves the articles") {
                                    expect(dataService.saveCallCount) == 1
                                    let args = dataService.saveCallArgs.first

                                    expect(args?.0.count) == 0
                                    expect(args?.1.count) == 2
                                    
                                    expect(args?.1) == [article2, article3]
                                }

                                describe("when the timer fires") {
                                    beforeEach {
                                        expect(timerFactory.nonrepeatingTimerCallCount) == 1

                                        guard timerFactory.nonrepeatingTimerCallCount == 1 else { return }

                                        let args = timerFactory.nonrepeatingTimerArgsForCall(0)

                                        args.2(Timer())
                                    }

                                    it("behaves as if we called -updateAllUnsyncedArticles() again") {
                                        expect(workQueue.operationCount) == 1
                                        expect(mainQueue.operationCount) == 0

                                        expect(workQueue.internalOperations.first).to(beAKindOf(FutureOperation.self))

                                        expect(workQueue.internalOperations.first?.dependencies.count) == 0
                                        
                                        expect(workQueue.internalOperations.first?.qualityOfService) == .utility
                                    }
                                }
                            }
                        }
                    }
                }
            }
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

                    subject.update(articles: [article])
                }

                it("does nothing") {
                    expect(workQueue.operationCount) == 0
                    expect(mainQueue.operationCount) == 0
                }
            }

            context("when the user is logged in") {
                beforeEach {
                    accountRepository.backendRepositoryReturns(repository)

                    subject.update(articles: [article])
                }

                it("adds two operations to the work queue") {
                    expect(workQueue.operationCount) == 2
                    expect(mainQueue.operationCount) == 0
                }

                it("first would run an UpdateArticleOperation at utility priority") {
                    expect(workQueue.internalOperations.first).to(beAKindOf(UpdateArticleOperation.self))

                    expect(workQueue.internalOperations.first?.qualityOfService) == .utility
                }

                it("uses the UpdateArticleOperation to update the article specified") {
                    guard let op = workQueue.internalOperations.first as? UpdateArticleOperation else {
                        fail("whoops")
                        return
                    }
                    expect(op.articles) == [article]
                }

                it("second it would run a FutureOperation that depends on the first operation") {
                    expect(workQueue.internalOperations.last).to(beAKindOf(FutureOperation.self))

                    expect(workQueue.internalOperations.last?.dependencies.count) == 1
                    expect(workQueue.internalOperations.last?.dependencies.first) === workQueue.internalOperations.first
                }

                describe("after the first operation runs successfully") {
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

                describe("when the first operation runs, but fails") {
                    beforeEach {
                        let markReadPromise = Promise<Result<Void, SinopeError>>()
                        repository.markReadReturns(markReadPromise.future)

                        markReadPromise.resolve(.failure(.unknown))

                        workQueue.runNextOperation()
                    }

                    it("does not add any further operations") {
                        expect(workQueue.operationCount) == 1
                        expect(mainQueue.operationCount) == 0
                    }

                    it("adds a timer to try again") {
                        expect(timerFactory.nonrepeatingTimerCallCount) == 1

                        guard timerFactory.nonrepeatingTimerCallCount == 1 else { return }

                        let args = timerFactory.nonrepeatingTimerArgsForCall(0)

                        expect(args.0.timeIntervalSinceNow) ≈ 30 ± 1e-2
                        expect(args.1) ≈ 60
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

                        describe("when the timer fires") {
                            beforeEach {
                                expect(timerFactory.nonrepeatingTimerCallCount) == 1

                                guard timerFactory.nonrepeatingTimerCallCount == 1 else { return }

                                let args = timerFactory.nonrepeatingTimerArgsForCall(0)

                                args.2(Timer())
                            }

                            it("behaves as if we called -updateAllUnsyncedArticles()") {
                                expect(workQueue.operationCount) == 1
                                expect(mainQueue.operationCount) == 0

                                expect(workQueue.internalOperations.first).to(beAKindOf(FutureOperation.self))

                                expect(workQueue.internalOperations.first?.dependencies.count) == 0

                                expect(workQueue.internalOperations.first?.qualityOfService) == .utility
                            }
                        }
                    }
                }
            }
        }
    }
}
