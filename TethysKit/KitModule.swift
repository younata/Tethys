import Foundation
import Ra
#if os(iOS)
    import CoreSpotlight
#endif
import Reachability
import Sponde

public let kMainQueue = "kMainQueue"
public let kBackgroundQueue = "kBackgroundQueue"

public final class KitModule: NSObject, Ra.InjectorModule {
    // swiftlint:disable function_body_length
    public func configureInjector(injector: Injector) {
        // Operation Queues
        let mainQueue = OperationQueue.main
        injector.bind(kMainQueue, to: mainQueue)
        injector.bind(URLSession.self, to: URLSession.shared)
        injector.bind(Analytics.self, to: BadAnalytics())

        var searchIndex: SearchIndex?
        let reachable: Reachable? = Reachability()

        #if os(iOS)
            searchIndex = CSSearchableIndex.default()
            injector.bind(SearchIndex.self, to: CSSearchableIndex.default())
        #endif

        let backgroundQueue = OperationQueue()
        backgroundQueue.qualityOfService = QualityOfService.utility
        backgroundQueue.maxConcurrentOperationCount = 1
        injector.bind(kBackgroundQueue, to: backgroundQueue)

        let urlSessionConfiguration = URLSessionConfiguration.default
        let urlSessionDelegate = TethysKitURLSessionDelegate()

        RealmMigrator.beginMigration()

        let urlSession = URLSession(configuration: urlSessionConfiguration,
            delegate: urlSessionDelegate,
            delegateQueue: OperationQueue())

        let realmQueue = OperationQueue()
        realmQueue.qualityOfService = .userInitiated
        realmQueue.maxConcurrentOperationCount = 1

        let dataServiceFactory = DataServiceFactory(mainQueue: mainQueue,
            realmQueue: realmQueue,
            searchIndex: searchIndex,
            bundle: Bundle(for: self.classForCoder),
            fileManager: FileManager.default)

        let updateService = UpdateService(
            dataServiceFactory: dataServiceFactory,
            urlSession: urlSession,
            urlSessionDelegate: urlSessionDelegate,
            workerQueue: backgroundQueue
        )

        let userDefaults = UserDefaults.standard

        let updateUseCase = DefaultUpdateUseCase(
            updateService: updateService,
            mainQueue: mainQueue,
            userDefaults: userDefaults
        )

        let dataRepository = DefaultDatabaseUseCase(mainQueue: mainQueue,
            reachable: reachable,
            dataServiceFactory: dataServiceFactory,
            updateUseCase: updateUseCase,
            databaseMigrator: DatabaseMigrator()
        )

        injector.bind(DatabaseUseCase.self, to: dataRepository)
        injector.bind(DefaultDatabaseUseCase.self, to: dataRepository)

        let opmlService = DefaultOPMLService(injector: injector)
        injector.bind(OPMLService.self, to: opmlService)
        injector.bind(MigrationUseCase.self, to: DefaultMigrationUseCase(injector: injector))
        injector.bind(ImportUseCase.self, toBlock: DefaultImportUseCase.init)

        let spondeService = Sponde.DefaultService(baseURL: URL(string: "https://autonoe.cfapps.io")!,
                                                  networkClient: URLSession.shared)
        let generateBookUseCase = DefaultGenerateBookUseCase(service: spondeService, mainQueue: mainQueue)
        injector.bind(GenerateBookUseCase.self, to: generateBookUseCase)
    }
    // swiftlint:enable function_body_length
}
