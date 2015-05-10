import Foundation
import Ra

func injector() -> Injector {
    let injector = Ra.Injector()
    injector.bind(DataManager.self) {
        return DataManagerMock()
    }
    return injector
}

func managedObjectContext() -> NSManagedObjectContext {
    let modelURL = NSBundle.mainBundle().URLForResource("RSSClient", withExtension: "momd")!
    let managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL)!

    let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
    var error : NSError? = nil
    persistentStoreCoordinator.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil, error: &error)
    assert(error == nil, "\(error!)")

    let managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
    managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
    return managedObjectContext
}

func createFeed(managedObjectContext: NSManagedObjectContext) -> Feed {
    let entityDescription = NSEntityDescription.entityForName("Feed", inManagedObjectContext: managedObjectContext)!
    return Feed(entity: entityDescription, insertIntoManagedObjectContext: managedObjectContext)
}

func createArticle(managedObjectContext: NSManagedObjectContext) -> Article {
    let entityDescription = NSEntityDescription.entityForName("Article", inManagedObjectContext: managedObjectContext)!
    return Article(entity: entityDescription, insertIntoManagedObjectContext: managedObjectContext)
}

func createEnclosure(managedObjectContext: NSManagedObjectContext) -> Enclosure {
    let entityDescription = NSEntityDescription.entityForName("Enclosure", inManagedObjectContext: managedObjectContext)!
    return Enclosure(entity: entityDescription, insertIntoManagedObjectContext: managedObjectContext)
}