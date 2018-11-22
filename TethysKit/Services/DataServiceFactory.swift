import RealmSwift

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
            let dataService = self.newDataService()
            self.existingDataService = dataService
            return dataService
        }
        set {
            self.existingDataService = newValue
        }
    }

    func newDataService() -> DataService {
        return RealmService(
            realmProvider: DefaultRealmProvider(configuration: Realm.Configuration.defaultConfiguration),
            mainQueue: self.mainQueue,
            workQueue: self.realmQueue,
            searchIndex: self.searchIndex
        )
    }
}
