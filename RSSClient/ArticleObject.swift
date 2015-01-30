//
//  ArticleObject.swift
//  RSSClient
//
//  Created by pivotal on 1/29/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation

class ArticleObject {
    var title : String = ""
    var link : String = ""
    var summary : String = ""
    var author : String = ""
    var published : NSDate = NSDate()
    var updatedAt : NSDate? = nil
    var content : String = ""
    var read : Bool = false
    var feed : FeedObject? = nil
    var flags : [String] = []
    var enclosures : [EnclosureObject] = []

    let objectID : NSManagedObjectID

    func updateFromArticle(article: Article) {
        if article.objectID != objectID {
            return
        }
        title = article.title
        link = article.link
        summary = article.summary
        author = article.author
        published = article.published
        updatedAt = article.updatedAt
        content = article.content
        read = article.read.boolValue
        flags = article.flags != nil ? article.flags as [String] : []
    }

    func synchronizeWithArticle(article: Article) {
        if article.objectID != objectID {
            return
        }
        article.title = title
        article.link = link
        article.summary = summary
        article.author = author
        article.published = published
        article.updatedAt = updatedAt
        article.content = content
        article.read = read
        article.flags = flags
        article.managedObjectContext?.save(nil)
    }

    init(tuple: (title: String, link: String, summary: String, author: String, published: NSDate, updatedAt: NSDate?, content: String, read: Bool, flags: [String], feed: FeedObject?, enclosures: [EnclosureObject]), objectID: NSManagedObjectID) {
        title = tuple.title
        link = tuple.link
        summary = tuple.summary
        author = tuple.author
        published = tuple.published
        updatedAt = tuple.updatedAt
        content = tuple.content
        read = tuple.read
        flags = tuple.flags
        feed = tuple.feed
        enclosures = tuple.enclosures
        self.objectID = objectID
    }

    init(article: Article) {
        objectID = article.objectID
        self.updateFromArticle(article)
    }

}