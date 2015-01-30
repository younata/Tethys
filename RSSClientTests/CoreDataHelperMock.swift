//
//  CoreDataHelperMock.swift
//  RSSClient
//
//  Created by pivotal on 1/29/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation

func fullyConfiguredManagedObjectContext() -> NSManagedObjectContext {
    let helper = CoreDataHelperMock()
    let managedObjectModel = helper.managedObjectModel()
    let persistentStoreCoordinator = helper.persistentStoreCoordinator(managedObjectModel)
    return helper.managedObjectContext(persistentStoreCoordinator)
}

class CoreDataHelperMock : CoreDataHelper {
    override func persistentStoreCoordinator(managedObjectModel: NSManagedObjectModel) -> NSPersistentStoreCoordinator {
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        persistentStoreCoordinator.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil, error: nil)
        return persistentStoreCoordinator
    }
}