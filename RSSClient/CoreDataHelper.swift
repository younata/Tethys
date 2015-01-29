//
//  CoreDataHelper.swift
//  RSSClient
//
//  Created by Rachel Brindle on 1/25/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation
import CoreData

func + <K,V>(a: Dictionary<K,V>, b: Dictionary<K,V>) -> Dictionary<K,V> {
    var d = Dictionary<K,V>()
    for (k, v) in a { d[k] = v }
    for (k, v) in b { d[k] = v }
    return d
}

class CoreDataHelper {
    
    // MARK: Creating
    
    func upsertEntity(entity: String, withProperties properties: [String: AnyObject], managedObjectContext: NSManagedObjectContext, createProperties: [String: AnyObject] = [:]) -> NSManagedObject {
        var predicateString = ""
        var predicateArgs : [AnyObject] = []
        
        let keys = Array(properties.keys)
        for (idx, key) in enumerate(keys) {
            if idx != 0 {
                predicateString += " AND "
            }
            predicateString += "\(key) == %@"
            predicateArgs.append(properties[key]!)
        }
        let predicate = NSPredicate(format: predicateString, predicateArgs)!
        
        if let r = entities(entity, matchingPredicate: predicate, managedObjectContext: managedObjectContext)?.first as? NSManagedObject {
            return r
        }
        
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName(entity, inManagedObjectContext: managedObjectContext)
        request.predicate = predicate
        
        let ret = NSEntityDescription.insertNewObjectForEntityForName(entity, inManagedObjectContext: managedObjectContext) as NSManagedObject
        let addProperties = createProperties + properties
        for key in Array(addProperties.keys) {
            ret.setValue(addProperties[key], forKey: key)
        }
        return ret
    }
    
    func entities(entity: String, matchingPredicate predicate: NSPredicate, managedObjectContext: NSManagedObjectContext, sortDescriptors: [NSSortDescriptor] = []) -> [AnyObject]? {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName(entity, inManagedObjectContext: managedObjectContext)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        var error : NSError? = nil
        var ret = managedObjectContext.executeFetchRequest(request, error: &error)
        if (ret == nil) {
            println("Error executing fetch request: \(error)")
            return []
        }
        return ret
    }

    
    func managedObjectModel() -> NSManagedObjectModel {
        var model : NSManagedObjectModel! = nil
        if let modelURL = NSBundle.mainBundle().URLForResource("RSSClient", withExtension: "momd") {
            model = NSManagedObjectModel(contentsOfURL: modelURL)!
        } else {
            model = NSManagedObjectModel.mergedModelFromBundles(NSBundle.allBundles())!
        }
        return model
    }
    
    func persistentStoreCoordinator(managedObjectModel: NSManagedObjectModel, storeType: String) -> NSPersistentStoreCoordinator {let applicationDocumentsDirectory: String = (NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).last as String)
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        if storeType == NSInMemoryStoreType {
            persistentStoreCoordinator.addPersistentStoreWithType(storeType, configuration: nil, URL: nil, options: nil, error: nil)
        } else {
            let storeURL = NSURL.fileURLWithPath(applicationDocumentsDirectory.stringByAppendingPathComponent("RSSClient.sqlite"))
            var error: NSError? = nil
            var options : [String: AnyObject] = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
            persistentStoreCoordinator.addPersistentStoreWithType(storeType, configuration: managedObjectModel.configurations.last as NSString?, URL: storeURL, options: options, error: &error)
            if (error != nil) {
                NSFileManager.defaultManager().removeItemAtURL(storeURL!, error: nil)
                error = nil
                persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: managedObjectModel.configurations.last as NSString?, URL: storeURL, options: options, error: &error)
                if (error != nil) {
                    println("Fatal error adding persistent data store: \(error!)")
                    fatalError("bye.")
                }
            }
        }
        
        return persistentStoreCoordinator
    }
    
    func managedObjectContext(persistentStoreCoordinator: NSPersistentStoreCoordinator) -> NSManagedObjectContext {
        let managedObjectContext = NSManagedObjectContext()
        managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        return managedObjectContext
    }
}