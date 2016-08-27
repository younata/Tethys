import Foundation
import Ra
import CoreData
#if os(iOS)
    import CoreSpotlight
    import Reachability
#endif
import Sinope

public let kMainQueue = "kMainQueue"
public let kBackgroundQueue = "kBackgroundQueue"

public class KitModule: NSObject, Ra.InjectorModule {
    public func configureInjector(injector: Injector) {
        // Operation Queues
        let mainQueue = NSOperationQueue.mainQueue()
        injector.bind(kMainQueue, toInstance: mainQueue)

        injector.bind(NSURLSession.self, toInstance: NSURLSession.sharedSession())

        injector.bind(Analytics.self, toInstance: MixPanelAnalytics())

        var searchIndex: SearchIndex? = nil
        var reachable: Reachable? = nil

        #if os(iOS)
            searchIndex = CSSearchableIndex.defaultSearchableIndex()
            injector.bind(SearchIndex.self, toInstance: CSSearchableIndex.defaultSearchableIndex())
            reachable = try? Reachability.reachabilityForInternetConnection()
        #endif

        let backgroundQueue = NSOperationQueue()
        backgroundQueue.qualityOfService = NSQualityOfService.Utility
        backgroundQueue.maxConcurrentOperationCount = 1
        injector.bind(kBackgroundQueue, toInstance: backgroundQueue)

        let urlSessionConfiguration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(
            "com.rachelbrindle.rnews"
        )
        urlSessionConfiguration.discretionary = false
        let urlSessionDelegate = URLSessionDelegate()

        RealmMigrator.beginMigration()

        let urlSession = NSURLSession(configuration: urlSessionConfiguration,
            delegate: urlSessionDelegate,
            delegateQueue: NSOperationQueue())

        let realmQueue = NSOperationQueue()
        realmQueue.qualityOfService = .UserInitiated
        realmQueue.maxConcurrentOperationCount = 1

        let dataServiceFactory = DataServiceFactory(mainQueue: mainQueue,
            realmQueue: realmQueue,
            searchIndex: searchIndex,
            bundle: NSBundle(forClass: self.classForCoder),
            fileManager: NSFileManager.defaultManager())

        let sinopeRepository = PasiphaeFactory().repository(NSURLSession.sharedSession())

        let updateService = UpdateService(
            dataServiceFactory: dataServiceFactory,
            urlSession: urlSession,
            urlSessionDelegate: urlSessionDelegate,
            workerQueue: backgroundQueue,
            sinopeRepository: sinopeRepository
        )

        let userDefaults = NSUserDefaults.standardUserDefaults()
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

        injector.bind(DatabaseUseCase.self, toInstance: dataRepository)
        injector.bind(DefaultDatabaseUseCase.self, toInstance: dataRepository)
        injector.bind(AccountRepository.self, toInstance: accountRepository)

        let opmlService = OPMLService(injector: injector)
        injector.bind(OPMLService.self, toInstance: opmlService)

        injector.bind(MigrationUseCase.self, toInstance: DefaultMigrationUseCase(injector: injector))
        injector.bind(ImportUseCase.self, to: DefaultImportUseCase.init)

    }
}
