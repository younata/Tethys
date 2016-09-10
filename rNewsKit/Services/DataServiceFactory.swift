import RealmSwift
import CoreData

protocol DataServiceFactoryType: class {
    var currentDataService: DataService { get set }

    func newDataService() -> DataService
}

final class DataServiceFactory: DataServiceFactoryType {
    private let mainQueue: OperationQueue
    private let realmQueue: OperationQueue
    private let searchIndex: SearchIndex?
    private let bundle: Bundle
    private let fileManager: FileManager


    init(mainQueue: OperationQueue,
        realmQueue: OperationQueue,
        searchIndex: SearchIndex?,
        bundle: Bundle,
        fileManager: FileManager) {
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
        return !self.fileManager.fileExists(atPath: url.path )
    }

    private func coreDataService() -> CoreDataService {
        let modelURL = self.bundle.url(forResource: "RSSClient", withExtension: "momd")!
        let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)!

        let storeURL = URL(fileURLWithPath: documentsDirectory() + "/RSSClient.sqlite")
        let persistentStore = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        let options: [String: AnyObject] = [NSMigratePersistentStoresAutomaticallyOption: true as AnyObject,
            NSInferMappingModelAutomaticallyOption: true as AnyObject]
        do {
            try persistentStore.addPersistentStore(ofType: NSSQLiteStoreType,
                configurationName: managedObjectModel.configurations.last,
                at: storeURL, options: options)
        } catch {
            fatalError()
        }
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = persistentStore
        managedObjectContext.undoManager = nil

        return CoreDataService(
            managedObjectContext: managedObjectContext,
            mainQueue: mainQueue,
            searchIndex: searchIndex
        )
    }
}
