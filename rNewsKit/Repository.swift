import CBGPromise
import Result

enum RepositoryError: ErrorType {
    case Unknown
}

protocol Repository {
    associatedtype Data

    func get() -> Future<Result<[Data], RepositoryError>>
    func create() -> Future<Result<Data, RepositoryError>>
    func save(data: Data) -> Future<Result<Void, RepositoryError>>
    func delete(data: Data) -> Future<Result<Void, RepositoryError>>
}

class FeedRepository: Repository {
    private let dataService: DataService

    init(dataService: DataService) {
        self.dataService = dataService
    }

    private var _feeds: [Feed]? = nil
    func get() -> Future<Result<[Feed], RepositoryError>> {
        let promise = Promise<Result<[Feed], RepositoryError>>()
        promise.resolve(Result(error: .Unknown))
        return promise.future
    }

    func create() -> Future<Result<Feed, RepositoryError>> {
        let promise = Promise<Result<Feed, RepositoryError>>()
        self.dataService.createFeed {
            promise.resolve(Result(value: $0))
        }
        return promise.future
    }

    func save(data: Feed) -> Future<Result<Void, RepositoryError>> {
        self._feeds = nil
        return self.dataService.saveFeed(data).map { _ -> Result<Void, RepositoryError> in
            return Result(error: .Unknown)
        }
    }

    func delete(data: Feed) -> Future<Result<Void, RepositoryError>> {
        self._feeds = self._feeds?.filter { $0 != data }

        return self.dataService.deleteFeed(data).map { _ -> Result<Void, RepositoryError> in
            return Result(error: .Unknown)
        }
    }
}
