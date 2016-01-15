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

        let objectContext = ManagedObjectContext()
        let dataService = CoreDataService(
            managedObjectContext: objectContext,
            mainQueue: mainQueue,
            searchIndex: searchIndex
        )
        injector.bind(DataService.self, toInstance: dataService)

        let urlSessionConfiguration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(
            "com.rachelbrindle.rnews"
        )
        urlSessionConfiguration.discretionary = false
        let urlSessionDelegate = URLSessionDelegate()

        let urlSession = NSURLSession(configuration: urlSessionConfiguration,
            delegate: urlSessionDelegate,
            delegateQueue: NSOperationQueue())

        let updateService = UpdateService(
            dataService: dataService,
            urlSession: urlSession,
            urlSessionDelegate: urlSessionDelegate
        )

        let dataRepository = DataRepository(mainQueue: mainQueue,
            backgroundQueue: backgroundQueue,
            reachable: reachable,
            dataService: dataService,
            updateService: updateService
        )

        injector.bind(DataRetriever.self, toInstance: dataRepository)
        injector.bind(DataWriter.self, toInstance: dataRepository)
        injector.bind(DataRepository.self, toInstance: dataRepository)

        let opmlService = OPMLService(injector: injector)
        injector.bind(OPMLService.self, toInstance: opmlService)
    }

    private func ManagedObjectContext() -> NSManagedObjectContext {
        let modelURL = NSBundle(forClass: self.classForCoder).URLForResource("RSSClient", withExtension: "momd")!
        let managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL)!

        let storeURL = NSURL.fileURLWithPath(documentsDirectory().stringByAppendingPathComponent("RSSClient.sqlite"))
        let persistentStore = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        let options: [String: AnyObject] = [NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true]
        do {
            try persistentStore.addPersistentStoreWithType(NSSQLiteStoreType,
                configuration: managedObjectModel.configurations.last,
                URL: storeURL, options: options)
        } catch {
            fatalError()
        }
        let ctx = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        ctx.persistentStoreCoordinator = persistentStore
        return ctx
    }
}
