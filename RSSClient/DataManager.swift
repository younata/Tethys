//
//  DataManager.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation
import CoreData

private let instance = DataManager()

class DataManager {
    class func sharedInstance() -> DataManager {
        return instance
    }
    
    func feeds() -> [Feed] {
        return (self.entities("Feed", matchingPredicate: NSPredicate(value: true)) as [Feed])
    }
    
    func entities(entity: String, matchingPredicate predicate: NSPredicate) -> [AnyObject] {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName(entity, inManagedObjectContext: managedObjectContext)
        request.predicate = predicate
        
        var error : NSError? = nil
        var ret = managedObjectContext.executeFetchRequest(request, error: &error)
        if (ret == nil) {
            println("Error executing fetch request: \(error)")
            return []
        }
        return ret!
    }
    
    func saveContext() {
        var error: NSError? = nil
        if (managedObjectContext.hasChanges && !managedObjectContext.save(&error)) {
            println("Error saving context: \(error)")
            fatalError("Error saving context")
        }
    }
    
    let managedObjectModel: NSManagedObjectModel
    let persistentStoreCoordinator: NSPersistentStoreCoordinator
    let managedObjectContext: NSManagedObjectContext
    
    init() {
        managedObjectModel = NSManagedObjectModel.mergedModelFromBundles(nil)
        let applicationDocumentsDirectory: String = (NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).last as String)
        let storeURL = NSURL.fileURLWithPath(applicationDocumentsDirectory.stringByAppendingPathComponent("RSSClient.sqlite"))
        persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        var error: NSError? = nil
        persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: nil, error: &error)
        
        managedObjectContext = NSManagedObjectContext()
        managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
    }
}