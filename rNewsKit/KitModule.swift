import Foundation
import Ra
import CoreData
#if os(iOS)
    import CoreSpotlight
#endif

internal let kBackgroundManagedObjectContext = "kBackgroundManagedObjectContext"

public let kMainQueue = "kMainQueue"
public let kBackgroundQueue = "kBackgroundQueue"

public class KitModule: NSObject, Ra.InjectorModule {
    public func configureInjector(injector: Injector) {
        // Operation Queues
        let mainQueue = NSOperationQueue.mainQueue()
        injector.bind(kMainQueue, to: mainQueue)

        injector.bind(NSURLSession.self, to: NSURLSession.sharedSession())

        var searchIndex: SearchIndex? = nil

        #if os(iOS)
            if #available(iOS 9.0, *) {
                searchIndex = CSSearchableIndex.defaultSearchableIndex()
                injector.bind(SearchIndex.self, to: searchIndex!)
            }
        #endif

        let backgroundQueue = NSOperationQueue()
        backgroundQueue.qualityOfService = NSQualityOfService.Utility
        backgroundQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount
        injector.bind(kBackgroundQueue, to: backgroundQueue)

        let dataRepository = DataRepository(objectContext: ManagedObjectContext(), mainQueue: mainQueue, backgroundQueue: backgroundQueue, urlSession: NSURLSession.sharedSession(), searchIndex: searchIndex)

        injector.bind(DataRetriever.self, to: dataRepository)
        injector.bind(DataWriter.self, to: dataRepository)
        injector.bind(DataRepository.self, to: dataRepository)

        let opmlManager = OPMLManager(injector: injector)
        injector.bind(OPMLManager.self, to: opmlManager)
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