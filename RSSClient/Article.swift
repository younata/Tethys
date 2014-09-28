//
//  Article.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation
import CoreData

class Article: NSManagedObject {

    @NSManaged var title: String
    @NSManaged var link: String
    @NSManaged var summary: String
    @NSManaged var author: String
    @NSManaged var published: NSDate
    @NSManaged var enclosure: AnyObject
    @NSManaged var updatedAt: NSDate?
    @NSManaged var identifier: String
    @NSManaged var content: String?
    @NSManaged var read: Bool
    @NSManaged var feed: Feed

}
