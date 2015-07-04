import Foundation
import Ra
import CoreData
@testable import rNewsKit

func managedObjectContext() -> NSManagedObjectContext {
    let bundle = NSBundle(forClass: DataRepository.self)
    let modelURL = bundle.URLForResource("RSSClient", withExtension: "momd")!
    let managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL)!

    let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
    var error : NSError? = nil
    do {
        try persistentStoreCoordinator.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil)
    } catch let error1 as NSError {
        error = error1
    }
    assert(error == nil, "\(error!)")

    let managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
    managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
    return managedObjectContext
}

func createFeed(managedObjectContext: NSManagedObjectContext) -> CoreDataFeed {
    let entityDescription = NSEntityDescription.entityForName("Feed", inManagedObjectContext: managedObjectContext)!
    return CoreDataFeed(entity: entityDescription, insertIntoManagedObjectContext: managedObjectContext)
}

func createArticle(managedObjectContext: NSManagedObjectContext) -> CoreDataArticle {
    let entityDescription = NSEntityDescription.entityForName("Article", inManagedObjectContext: managedObjectContext)!
    return CoreDataArticle(entity: entityDescription, insertIntoManagedObjectContext: managedObjectContext)
}

func createEnclosure(managedObjectContext: NSManagedObjectContext) -> CoreDataEnclosure {
    let entityDescription = NSEntityDescription.entityForName("Enclosure", inManagedObjectContext: managedObjectContext)!
    return CoreDataEnclosure(entity: entityDescription, insertIntoManagedObjectContext: managedObjectContext)
}