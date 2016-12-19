import Foundation
import Ra

public final class SyncManager: Injectable {
    private let workQueue: OperationQueue
    private let mainQueue: OperationQueue
    private let dataServiceFactory: DataServiceFactoryType
    private let accountRepository: InternalAccountRepository

    private var dataService: DataService {
        return self.dataServiceFactory.currentDataService
    }

    init(workQueue: OperationQueue,
         mainQueue: OperationQueue,
         dataServiceFactory: DataServiceFactoryType,
         accountRepository: InternalAccountRepository) {
        self.workQueue = workQueue
        self.mainQueue = mainQueue
        self.dataServiceFactory = dataServiceFactory
        self.accountRepository = accountRepository
    }

    public required convenience init(injector: Injector) {
        self.init(
            workQueue: injector.create(kind: OperationQueue.self)!,
            mainQueue: injector.create(string: kMainQueue) as! OperationQueue,
            dataServiceFactory: injector.create(kind: DataServiceFactoryType.self)!,
            accountRepository: injector.create(kind: InternalAccountRepository.self)!
        )
    }

    public func update(article: Article) {
        if let repository = self.accountRepository.backendRepository() {
            let updateOperation = UpdateArticleOperation(article: article, backendRepository: repository)
            updateOperation.qualityOfService = .utility

            let saveOperation = FutureOperation {
                return self.dataService.batchSave([], articles: [article]).map { _ in return }
            }

            saveOperation.addDependency(updateOperation)
            saveOperation.qualityOfService = .utility

            self.workQueue.addOperations([updateOperation, saveOperation], waitUntilFinished: false)
        }
    }
}
