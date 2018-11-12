import Foundation
import Swinject
#if os(iOS)
    import CoreSpotlight
#endif
import Reachability
import Sponde

public let kMainQueue = "kMainQueue"
public let kBackgroundQueue = "kBackgroundQueue"
private let kRealmQueue = "kRealmQueue"

public func configure(container: Container) {
    container.register(OperationQueue.self, name: kMainQueue) { _ in OperationQueue.main}
    container.register(OperationQueue.self, name: kBackgroundQueue) { _ in
        let backgroundQueue = OperationQueue()
        backgroundQueue.qualityOfService = QualityOfService.utility
        backgroundQueue.maxConcurrentOperationCount = 1
        return backgroundQueue
    }.inObjectScope(.container)
    container.register(OperationQueue.self, name: kRealmQueue) { _ in
        let realmQueue = OperationQueue()
        realmQueue.qualityOfService = .userInitiated
        realmQueue.maxConcurrentOperationCount = 1
        return realmQueue
    }.inObjectScope(.container)

    container.register(URLSession.self) { _ in URLSession.shared }
    container.register(FileManager.self) { _ in return FileManager.default }
    container.register(UserDefaults.self) { _ in return UserDefaults.standard }
    container.register(Bundle.self) { _ in Bundle(for: WebPageParser.classForCoder() )}
    container.register(Analytics.self) { _ in BadAnalytics() }.inObjectScope(.container)

    container.register(Reachable.self) { _ in Reachability()! }

    #if os(iOS)
    container.register(SearchIndex.self) { _ in CSSearchableIndex.default() }
    #endif

    container.register(TethysKitURLSessionDelegate.self) { _ in
        return TethysKitURLSessionDelegate()
    }.inObjectScope(.container)

    RealmMigrator.beginMigration()

    container.register(URLSession.self) { r in
        return URLSession(
            configuration: .default,
            delegate: r.resolve(TethysKitURLSessionDelegate.self)!,
            delegateQueue: OperationQueue()
        )
    }

    container.register(DatabaseMigratorType.self) { _ in
        return DatabaseMigrator()
    }

    container.register(DataServiceFactoryType.self) { r in
        return DataServiceFactory(
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            realmQueue: r.resolve(OperationQueue.self, name: kRealmQueue)!,
            searchIndex: r.resolve(SearchIndex.self),
            bundle: r.resolve(Bundle.self)!,
            fileManager: r.resolve(FileManager.self)!
        )
    }

    container.register(UpdateServiceType.self) { r in
        return UpdateService(
            dataServiceFactory: r.resolve(DataServiceFactoryType.self)!,
            urlSession: r.resolve(URLSession.self)!,
            urlSessionDelegate: r.resolve(TethysKitURLSessionDelegate.self)!,
            workerQueue: r.resolve(OperationQueue.self, name: kBackgroundQueue)!
        )
    }

    container.register(UpdateUseCase.self) { r in
        return DefaultUpdateUseCase(
            updateService: r.resolve(UpdateServiceType.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            userDefaults: r.resolve(UserDefaults.self)!
        )
    }

    container.register(DatabaseUseCase.self) { r in
        return DefaultDatabaseUseCase(
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            reachable: r.resolve(Reachability.self),
            dataServiceFactory: r.resolve(DataServiceFactoryType.self)!,
            updateUseCase: r.resolve(UpdateUseCase.self)!,
            databaseMigrator: r.resolve(DatabaseMigratorType.self)!
        )
    }

    container.register(OPMLService.self) { r in
        return DefaultOPMLService(
            dataRepository: r.resolve(DatabaseUseCase.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            importQueue: r.resolve(OperationQueue.self, name: kBackgroundQueue)!
        )
    }

    container.register(MigrationUseCase.self) { r in
        return DefaultMigrationUseCase(feedRepository: r.resolve(DatabaseUseCase.self)!)
    }

    container.register(ImportUseCase.self) { r in
        return DefaultImportUseCase(
            urlSession: r.resolve(URLSession.self)!,
            feedRepository: r.resolve(DatabaseUseCase.self)!,
            opmlService: r.resolve(OPMLService.self)!,
            fileManager: r.resolve(FileManager.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!
        )
    }

    container.register(GenerateBookUseCase.self) { r in
        return DefaultGenerateBookUseCase(
            service: Sponde.DefaultService(baseURL: URL(string: "https://autonoe.cfapps.io")!,
                                           networkClient: URLSession.shared),
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!
        )
    }
}
