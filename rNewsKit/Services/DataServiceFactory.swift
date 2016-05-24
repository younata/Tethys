import RealmSwift
import CoreData

protocol DataServiceFactoryType: class {
    var currentDataService: DataService { get set }

    func newDataService() -> DataService
}

final class DataServiceFactory: DataServiceFactoryType {
    private let mainQueue: NSOperationQueue
    private let realmQueue: NSOperationQueue
    private let searchIndex: SearchIndex?
    private let bundle: NSBundle
    private let fileManager: NSFileManager


    init(mainQueue: NSOperationQueue,
        realmQueue: NSOperationQueue,
        searchIndex: SearchIndex?,
        bundle: NSBundle,
        fileManager: NSFileManager) {
            self.mainQueue = mainQueue
            self.realmQueue = realmQueue
            self.searchIndex = searchIndex
            self.bundle = bundle
            self.fileManager = fileManager
    }

    private var existingDataService: DataService?
    var currentDataService: DataService {
        get {
            if let dataService = self.existingDataService {
                return dataService
            }
            let dataService: DataService
            if self.useCoreData() {
                dataService = self.coreDataService()
            } else {
                dataService = self.newDataService()
            }
            self.existingDataService = dataService
            return dataService
        }
        set {
            self.existingDataService = newValue
        }
    }

    func newDataService() -> DataService {
        return RealmService(realmConfiguration: Realm.Configuration.defaultConfiguration,
            mainQueue: self.mainQueue,
            workQueue: self.realmQueue,
            searchIndex: self.searchIndex)
    }

    private func useCoreData() -> Bool {
        guard let url = Realm.Configuration.defaultConfiguration.fileURL else { return true }
        return !self.fileManager.fileExistsAtPath(url.path ?? "")
    }

    private func coreDataService() -> CoreDataService {
        let modelURL = self.bundle.URLForResource("RSSClient", withExtension: "momd")!
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
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = persistentStore
        managedObjectContext.undoManager = nil

        return CoreDataService(
            managedObjectContext: managedObjectContext,
            mainQueue: mainQueue,
            searchIndex: searchIndex
        )
    }
}
