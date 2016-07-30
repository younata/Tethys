import Sinope

final class DefaultAccountRepositoryDelegate: AccountRepositoryDelegate {
    private let databaseUseCase: DatabaseUseCase
    private let mainQueue: NSOperationQueue

    init(databaseUseCase: DatabaseUseCase, mainQueue: NSOperationQueue) {
        self.databaseUseCase = databaseUseCase
        self.mainQueue = mainQueue
    }

    func accountRepositoryDidLogIn(accountRepository: InternalAccountRepository) {
        self.databaseUseCase.feeds().then { feedsResult in
            switch feedsResult {
            case let .Success(feeds):
                let urls = feeds.flatMap { $0.url }
                if let sinopeRepository = accountRepository.backendRepository() {
                    self.subscribeToUrls(urls, sinopeRepository: sinopeRepository)
                }
            case .Failure(_):
                break
            }
        }
    }

    private func subscribeToUrls(urls: [NSURL], sinopeRepository: Sinope.Repository) {
        sinopeRepository.subscribe(urls).then { subscribeResult in
            switch subscribeResult {
            case .Success(_):
                self.mainQueue.addOperationWithBlock {
                    self.databaseUseCase.updateFeeds { _ in }
                }
            case .Failure(_):
                break
            }
        }
    }
}
