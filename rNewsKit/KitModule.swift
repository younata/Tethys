import Foundation
import Ra
#if os(iOS)
    import CoreSpotlight
#endif
import Reachability
import Sinope
import Sponde

public let kMainQueue = "kMainQueue"
public let kBackgroundQueue = "kBackgroundQueue"

public final class KitModule: NSObject, Ra.InjectorModule {
    // swiftlint:disable function_body_length
    public func configureInjector(injector: Injector) {
        // Operation Queues
        let mainQueue = OperationQueue.main
        injector.bind(string: kMainQueue, toInstance: mainQueue)
        injector.bind(kind: URLSession.self, toInstance: URLSession.shared)
        #if os(iOS)
            injector.bind(kind: Analytics.self, toInstance: MixPanelAnalytics())
        #endif

        var searchIndex: SearchIndex? = nil
        let reachable: Reachable? = Reachability()

        #if os(iOS)
            searchIndex = CSSearchableIndex.default()
            injector.bind(kind: SearchIndex.self, toInstance: CSSearchableIndex.default())
        #endif

        let backgroundQueue = OperationQueue()
        backgroundQueue.qualityOfService = QualityOfService.utility
        backgroundQueue.maxConcurrentOperationCount = 1
        injector.bind(string: kBackgroundQueue, toInstance: backgroundQueue)

        let urlSessionConfiguration = URLSessionConfiguration.default
        let urlSessionDelegate = RNewsKitURLSessionDelegate()

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

        let sinopeRepository = PasiphaeFactory().repository(URLSession.shared)

        let updateService = UpdateService(
            dataServiceFactory: dataServiceFactory,
            urlSession: urlSession,
            urlSessionDelegate: urlSessionDelegate,
            workerQueue: backgroundQueue,
            sinopeRepository: sinopeRepository
        )

        let userDefaults = UserDefaults.standard
        let accountRepository = DefaultAccountRepository(repository: sinopeRepository,
                                                         userDefaults: userDefaults)

        let updateUseCase = DefaultUpdateUseCase(
            updateService: updateService,
            mainQueue: mainQueue,
            accountRepository: accountRepository,
            userDefaults: userDefaults
        )

        let dataRepository = DefaultDatabaseUseCase(mainQueue: mainQueue,
            reachable: reachable,
            dataServiceFactory: dataServiceFactory,
            updateUseCase: updateUseCase,
            databaseMigrator: DatabaseMigrator(),
            accountRepository: accountRepository
        )

        accountRepository.delegate = DefaultAccountRepositoryDelegate(
            databaseUseCase: dataRepository,
            mainQueue: mainQueue
        )

        injector.bind(kind: DatabaseUseCase.self, toInstance: dataRepository)
        injector.bind(kind: DefaultDatabaseUseCase.self, toInstance: dataRepository)
        injector.bind(kind: AccountRepository.self, toInstance: accountRepository)

        let opmlService = DefaultOPMLService(injector: injector)
        injector.bind(kind: OPMLService.self, toInstance: opmlService)
        injector.bind(kind: MigrationUseCase.self, toInstance: DefaultMigrationUseCase(injector: injector))
        injector.bind(kind: ImportUseCase.self, to: DefaultImportUseCase.init)

        let spondeService = Sponde.DefaultService(baseURL: URL(string: "https://autonoe.cfapps.io")!,
                                                  networkClient: URLSession.shared)
        let generateBookUseCase = DefaultGenerateBookUseCase(service: spondeService, mainQueue: mainQueue)
        injector.bind(kind: GenerateBookUseCase.self, toInstance: generateBookUseCase)
    }
    // swiftlint:enable function_body_length
}
