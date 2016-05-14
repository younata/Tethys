import Ra
import WorkFlow

public protocol MigrationUseCaseSubscriber: class {
    func migrationUseCaseDidFinish(migrationUseCase: MigrationUseCase)
    func migrationUseCase(migrationUseCase: MigrationUseCase, didUpdateProgress progress: Double)
}

public protocol MigrationUseCase: WorkFlowComponent {
    func addSubscriber(subscriber: MigrationUseCaseSubscriber)
    func beginMigration()
}

public class DefaultMigrationUseCase: MigrationUseCase, Injectable {
    private let feedRepository: DatabaseUseCase

    public init(feedRepository: DatabaseUseCase) {
        self.feedRepository = feedRepository
    }

    public required convenience init(injector: Injector) {
        self.init(
            feedRepository: injector.create(DatabaseUseCase)!
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
        self.feedRepository.performDatabaseUpdates(self.updateProgress) {
            self.subscribers.forEach { $0.migrationUseCaseDidFinish(self) }
            for callback in self.workFlowCallbacks {
                callback()
            }
            self.workFlowCallbacks.removeAll()
        }
    }

    private var workFlowCallbacks: [WorkFlowFinishCallback] = []
    public func beginWork(finish: WorkFlowFinishCallback) {
        self.workFlowCallbacks.append(finish)
        self.beginMigration()
    }

    private func updateProgress(progress: Double) {
        self.subscribers.forEach { $0.migrationUseCase(self, didUpdateProgress: progress) }
    }
}
