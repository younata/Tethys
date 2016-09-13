import Foundation
import Ra
import CoreData
@testable import rNewsKit

func managedObjectContext() -> NSManagedObjectContext {
    let bundle = Bundle(for: DefaultDatabaseUseCase.self)
    let modelURL = bundle.url(forResource: "RSSClient", withExtension: "momd")!
    let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)!

    let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
    var error: NSError? = nil
    do {
        try persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
    } catch let error1 as NSError {
        error = error1
    }
    assert(error == nil, "\(error!)")

    let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
    return managedObjectContext
}

func createFeed(managedObjectContext: NSManagedObjectContext) -> CoreDataFeed {
    let entityDescription = NSEntityDescription.entity(forEntityName: "Feed", in: managedObjectContext)!
    return CoreDataFeed(entity: entityDescription, insertInto: managedObjectContext)
}

func createArticle(managedObjectContext: NSManagedObjectContext) -> CoreDataArticle {
    let entityDescription = NSEntityDescription.entity(forEntityName: "Article", in: managedObjectContext)!
    return CoreDataArticle(entity: entityDescription, insertInto: managedObjectContext)
}
