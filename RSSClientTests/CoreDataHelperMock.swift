//
//  CoreDataHelperMock.swift
//  RSSClient
//
//  Created by pivotal on 1/29/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation

class CoreDataHelperMock : CoreDataHelper {
    override func upsertEntity(entity: String, withProperties properties: [String : AnyObject], managedObjectContext: NSManagedObjectContext, createProperties: [String : AnyObject]) -> NSManagedObject {
        return NSManagedObject()
    }

    override func entities(entity: String, matchingPredicate predicate: NSPredicate, managedObjectContext: NSManagedObjectContext, sortDescriptors: [NSSortDescriptor]) -> [AnyObject]? {
        return nil
    }

    override func managedObjectModel() -> NSManagedObjectModel {
        return NSManagedObjectModel()
    }

    override func persistentStoreCoordinator(managedObjectModel: NSManagedObjectModel, storeType: String) -> NSPersistentStoreCoordinator {
        return NSPersistentStoreCoordinator()
    }

    override func managedObjectContext(persistentStoreCoordinator: NSPersistentStoreCoordinator) -> NSManagedObjectContext {
        return NSManagedObjectContext()
    }
}