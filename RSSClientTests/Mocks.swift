//
//  Mocks.swift
//  RSSClient
//
//  Created by Rachel Brindle on 10/8/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation

class FakeFeed : Feed {
    init() {
        let entity = NSEntityDescription()
        entity.name = "Feed"
        super.init(entity: entity, insertIntoManagedObjectContext: nil)
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext!) {
        super.init(entity: entity, insertIntoManagedObjectContext: nil)
    }
    
    class func newFeed() -> FakeFeed {
        let entity = NSEntityDescription()
        entity.name = "Feed"
        return FakeFeed(entity: entity, insertIntoManagedObjectContext: nil)
    }
    
    override var image: AnyObject! {
        get {
            return nil
        }
        set {
            
        }
    }
    
    override var title : String? {
        get {
            return "test"
        }
        set {
            
        }
    }
    
    override var summary : String? {
        get {
            return "test summary"
        }
        set {
            
        }
    }
    
    override var articles : NSSet? {
        get {
            var a1 = FakeArticle.newArticle()
            var a2 = FakeArticle.newArticle()
            var a3 = FakeArticle.newArticle()
            return NSSet(array: [a1, a2, a3])
        }
        set {
            
        }
    }
}

class FakeArticle : Article {
    init() {
        let entity = NSEntityDescription()
        entity.name = "Article"
        super.init(entity: entity, insertIntoManagedObjectContext: nil)
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext!) {
        super.init(entity: entity, insertIntoManagedObjectContext: nil)
    }
    
    class func newArticle() -> FakeArticle {
        let entity = NSEntityDescription()
        entity.name = "Article"
        return FakeArticle(entity: entity, insertIntoManagedObjectContext: nil)
    }
    
    override var read : Bool {
        get {
            return false
        }
        set {
            
        }
    }
    
    override var title : String? {
        get {
            return "test"
        }
        set {
            
        }
    }
    
    override var published : NSDate? {
        get {
            return NSDate(timeIntervalSince1970: 1234567890)
        }
        set {
            
        }
    }
    
    override var author : String? {
        get {
            return "Rachel Brindle"
        }
        set {
            
        }
    }
    
    override var content : String? {
        get {
            return "test article"
        }
        set {
            
        }
    }
}