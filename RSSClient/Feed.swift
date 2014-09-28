//
//  Feed.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation
import CoreData

class Feed: NSManagedObject {

    @NSManaged var title: String
    @NSManaged var url: String
    @NSManaged var summary: String
    @NSManaged var image: AnyObject
    @NSManaged var articles: NSSet

}
