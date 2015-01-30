//
//  NSManagedObjectIDMock.swift
//  RSSClient
//
//  Created by pivotal on 1/29/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import CoreData

class NSManagedObjectIDMock : NSManagedObjectID {

    var uri : NSURL = NSURL(string: "https://example.com/object")!

    override func URIRepresentation() -> NSURL {
        return uri
    }
}
