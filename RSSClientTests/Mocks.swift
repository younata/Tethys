//
//  Mocks.swift
//  RSSClient
//
//  Created by Rachel Brindle on 10/8/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation

func newFeed(title: String = "test", summary: String = "test summary", image: UIImage? = nil, articles: [Article] = [newArticle(), newArticle(), newArticle()]) -> Feed {
    let feed = (newObject("Feed") as Feed)
    feed.title = title
    feed.summary = summary
    feed.image = nil
    feed.articles = NSSet(array: articles)
    DataManager.sharedInstance().managedObjectContext.save(nil)
    return feed
}

func newArticle(title: String = "test", published: NSDate = NSDate(), author: String = "Albert R. Hacker", content: String = "test article", read: Bool = false) -> Article {
    let article = (newObject("Article") as Article)
    article.title = title
    article.published = published
    article.author = author
    article.content = content
    article.read = read
    DataManager.sharedInstance().managedObjectContext.save(nil)
    return article
}

func newObject(name: String) -> NSManagedObject {
    return NSEntityDescription.insertNewObjectForEntityForName(name, inManagedObjectContext: DataManager.sharedInstance().managedObjectContext) as NSManagedObject
}