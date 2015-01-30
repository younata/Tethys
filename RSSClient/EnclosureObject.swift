//
//  EnclosureObject.swift
//  RSSClient
//
//  Created by pivotal on 1/29/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation

class EnclosureObject {
    var url : String = ""
    var kind : String = ""
    var data : NSData? = nil

    let objectID : NSManagedObjectID

    var downloaded: Bool {
        return data != nil
    }

    var article: ArticleObject? = nil

    func updateFromEnclosure(enclosure: Enclosure) {
        url = enclosure.url
        kind = enclosure.kind
        data = enclosure.data
    }

    func synchronizeWithEnclosure(enclosure: Enclosure) {
        enclosure.url = url
        enclosure.kind = kind
        enclosure.data = data
        enclosure.downloaded = downloaded
        enclosure.managedObjectContext?.save(nil)
    }

    init(tuple: (url: String, kind: String, data: NSData?), objectID: NSManagedObjectID) {
        url = tuple.url
        kind = tuple.kind
        data = tuple.data
        self.objectID = objectID
    }

    init(enclosure: Enclosure) {
        objectID = enclosure.objectID
        updateFromEnclosure(enclosure)
    }
}