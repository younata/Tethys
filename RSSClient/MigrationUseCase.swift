import Ra
import rNewsKit

public protocol MigrationUseCaseSubscriber: class {
    func migrationUseCaseDidFinish(migrationUseCase: MigrationUseCase)
}

public protocol MigrationUseCase {
    func addSubscriber(subscriber: MigrationUseCaseSubscriber)
    func beginMigration()
}

public struct DefaultMigrationUseCase: MigrationUseCase, Injectable {
    private let feedRepository: FeedRepository

    public init(feedRepository: FeedRepository) {
        self.feedRepository = feedRepository
    }

    public init(injector: Injector) {
        self.init(
            feedRepository: injector.create(FeedRepository)!
        )
    }

    private let _subscribers = NSHashTable.weakObjectsHashTable()
    private var subscribers: [MigrationUseCaseSubscriber] {
        return self._subscribers.allObjects.flatMap { $0 as? MigrationUseCaseSubscriber }
    }
    public func addSubscriber(subscriber: MigrationUseCaseSubscriber) {
        self._subscribers.addObject(subscriber)
    }

    public func beginMigration() {
        self.feedRepository.performDatabaseUpdates {
            self.subscribers.forEach { $0.migrationUseCaseDidFinish(self) }
        }
    }
}
