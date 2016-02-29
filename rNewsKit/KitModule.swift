import Foundation
import Ra
import CoreData
#if os(iOS)
    import CoreSpotlight
    import Reachability
#endif

public let kMainQueue = "kMainQueue"
public let kBackgroundQueue = "kBackgroundQueue"

public class KitModule: NSObject, Ra.InjectorModule {
    public func configureInjector(injector: Injector) {
        // Operation Queues
        let mainQueue = NSOperationQueue.mainQueue()
        injector.bind(kMainQueue, toInstance: mainQueue)

        injector.bind(NSURLSession.self, toInstance: NSURLSession.sharedSession())

        var searchIndex: SearchIndex? = nil
        var reachable: Reachable? = nil

        #if os(iOS)
            if #available(iOS 9.0, *) {
                searchIndex = CSSearchableIndex.defaultSearchableIndex()
                injector.bind(SearchIndex.self, toInstance: CSSearchableIndex.defaultSearchableIndex())
            }
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
        realmQueue.maxConcurrentOperationCount = 1
        realmQueue.qualityOfService = .UserInitiated

        let dataServiceFactory = DataServiceFactory(mainQueue: mainQueue,
            realmQueue: realmQueue,
            searchIndex: searchIndex,
            bundle: NSBundle(forClass: self.classForCoder),
            fileManager: NSFileManager.defaultManager())

        let updateService = UpdateService(
            dataServiceFactory: dataServiceFactory,
            urlSession: urlSession,
            urlSessionDelegate: urlSessionDelegate
        )

        let dataRepository = DataRepository(mainQueue: mainQueue,
            reachable: reachable,
            dataServiceFactory: dataServiceFactory,
            updateService: updateService,
            databaseMigrator: DatabaseMigrator()
        )

        injector.bind(FeedRepository.self, toInstance: dataRepository)
        injector.bind(DataRepository.self, toInstance: dataRepository)

        let opmlService = OPMLService(injector: injector)
        injector.bind(OPMLService.self, toInstance: opmlService)
    }
}
