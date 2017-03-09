import Foundation
import Ra
import Sinope

public protocol SyncManager: class {
    func updateAllUnsyncedArticles()
    func update(articles: [Article])
}

public final class SyncEngineManager: SyncManager, Injectable {
    private let workQueue: OperationQueue
    private let mainQueue: OperationQueue
    private let dataServiceFactory: DataServiceFactoryType
    private let accountRepository: InternalAccountRepository
    private let timerFactory: TimerFactory

    private var dataService: DataService {
        return self.dataServiceFactory.currentDataService
    }

    init(workQueue: OperationQueue,
         mainQueue: OperationQueue,
         dataServiceFactory: DataServiceFactoryType,
         accountRepository: InternalAccountRepository,
         timerFactory: TimerFactory) {
        self.workQueue = workQueue
        self.mainQueue = mainQueue
        self.dataServiceFactory = dataServiceFactory
        self.accountRepository = accountRepository
        self.timerFactory = timerFactory
    }

    public required convenience init(injector: Injector) {
        self.init(
            workQueue: injector.create(OperationQueue.self)!,
            mainQueue: injector.create(kMainQueue, type: OperationQueue.self)!,
            dataServiceFactory: injector.create(DataServiceFactoryType.self)!,
            accountRepository: injector.create(InternalAccountRepository.self)!,
            timerFactory: injector.create(TimerFactory.self)!
        )
    }

    public func updateAllUnsyncedArticles() {
        if let repository = self.accountRepository.backendRepository() {
            let retrieveArticlesOperation = FutureOperation {
                return self.dataService.articlesMatchingPredicate(NSPredicate(format: "synced = %@",
                                                                              false as CVarArg)).map { result -> Void in
                    switch result {
                    case let .success(articles):
                        if articles.count > 0 {
                            self.update(articles: Array(articles), repository: repository)
                        }
                    case .failure(_):
                        break
                    }
                }
            }

            retrieveArticlesOperation.qualityOfService = .utility

            self.workQueue.addOperation(retrieveArticlesOperation)
        }
    }

    public func update(articles: [Article]) {
        if let repository = self.accountRepository.backendRepository() {
            self.update(articles: articles, repository: repository)
        }
    }

    private func update(articles: [Article], repository: Repository) {
        let updateOperation = UpdateArticleOperation(articles: articles, backendRepository: repository)
        updateOperation.qualityOfService = .utility
        updateOperation.onCompletion = {
            switch $0 {
            case .success(_):
                break
            case .failure(_):
                self.timerFactory.nonrepeatingTimer(fireDate: Date(timeIntervalSinceNow: 30), tolerance: 60) { _ in
                    self.updateAllUnsyncedArticles()
                }
            }
        }

        let saveOperation = FutureOperation {
            return self.dataService.batchSave([], articles: articles).map { _ in return }
        }

        saveOperation.addDependency(updateOperation)
        saveOperation.qualityOfService = .utility

        self.workQueue.addOperations([updateOperation, saveOperation], waitUntilFinished: false)
    }
}
