import Sinope

final class DefaultAccountRepositoryDelegate: AccountRepositoryDelegate {
    private let databaseUseCase: DatabaseUseCase
    private let mainQueue: OperationQueue

    init(databaseUseCase: DatabaseUseCase, mainQueue: OperationQueue) {
        self.databaseUseCase = databaseUseCase
        self.mainQueue = mainQueue
    }

    func accountRepositoryDidLogIn(_ accountRepository: InternalAccountRepository) {
        _ = self.databaseUseCase.feeds().then { feedsResult in
            switch feedsResult {
            case let .success(feeds):
                let urls = feeds.flatMap { $0.url }
                if let sinopeRepository = accountRepository.backendRepository() {
                    self.subscribe(urls: urls, sinopeRepository: sinopeRepository)
                }
            case .failure(_):
                break
            }
        }
    }

    private func subscribe(urls: [URL], sinopeRepository: Sinope.Repository) {
        _ = sinopeRepository.subscribe(urls).then { subscribeResult in
            switch subscribeResult {
            case .success(_):
                self.mainQueue.addOperation {
                    self.databaseUseCase.updateFeeds { _ in }
                }
            case .failure(_):
                break
            }
        }
    }
}
