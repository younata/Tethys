//
//  Data-extensions.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/26/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation

extension Feed {
    func feedImage() -> Image? {
        if self.image == nil { return nil }
        return (self.image as Image)
    }
    
    func unreadArticles() -> UInt {
        return self.allArticles().reduce(0) {
            return $0 + ($1.read ? 0 : 1)
        }
    }
    
    func unreadArticles(dataManager: DataManager) -> UInt {
        return allArticles(dataManager).reduce(0) {
            return $0 + ($1.read ? 0 : 1)
        }
    }
    
    func allArticles() -> [Article] {
        return self.articles.allObjects as [Article]
    }
    
    func allArticles(dataManager: DataManager) -> [Article] {
        if let query = self.query {
            return dataManager.articlesMatchingQuery(query, feed: self)
        } else {
            return self.articles.allObjects as [Article]
        }
    }
    
    func isQueryFeed() -> Bool {
        return self.query != nil
    }
    
    func feedTitle() -> String? {
        return reduce(allTags(), self.title) {
            if $1.hasPrefix("~") {
                return $1.substringFromIndex($1.startIndex.successor())
            }
            return $0
        }
    }
    
    func feedSummary() -> String? {
        return reduce(allTags(), self.summary) {
            if $1.hasPrefix("`") {
                return $1.substringFromIndex($1.startIndex.successor())
            }
            return $0
        }
    }
    
    func allTags() -> [String] {
        return self.tags == nil ? [] : self.tags as [String]
    }
    
    func asDict() -> [String: AnyObject] {
        var ret = asDictNoArticles()
        var theArticles : [[String: AnyObject]] = []
        for article in articles.allObjects as [Article] {
            theArticles.append(article.asDictNoFeed())
        }
        ret["articles"] = theArticles
        return ret
    }
    
    func asDictNoArticles() -> [String: AnyObject] {
        var ret : [String: AnyObject] = [:]
        ret["title"] = title ?? ""
        ret["url"] = url ?? ""
        ret["summary"] = summary ?? ""
        ret["query"] = query ?? ""
        ret["tags"] = allTags()
        ret["id"] = self.objectID.description
        ret["remainingWait"] = remainingWait ?? 0
        ret["waitPeriod"] = waitPeriod ?? 0
        return ret
    }
    
    func waitPeriodInRefreshes(waitPeriod: Int) -> Int {
        var ret = 0, next = 1
        let wait = max(0, waitPeriod - 2)
        for i in 0..<wait {
            (ret, next) = (next, ret+next)
        }
        return ret
    }
}

extension Article {
    func allFlags() -> [String] {
        return self.flags == nil ? [] : self.flags as [String]
    }
    
    func allEnclosures() -> [Enclosure] {
        return self.enclosures == nil ? [] : self.enclosures.allObjects as [Enclosure]
    }
    
    func asDict() -> [String: AnyObject] {
        var ret = asDictNoFeed()
        if feed != nil {
            ret["feed"] = feed.asDictNoArticles()
        }
        return ret
    }
    
    func asDictNoFeed() -> [String: AnyObject] {
        var ret : [String: AnyObject] = [:]
        ret["title"] = title ?? ""
        ret["link"] = link ?? ""
        ret["summary"] = summary ?? ""
        ret["author"] = author ?? ""
        ret["published"] = published?.description ?? ""
        ret["updatedAt"] = updatedAt?.description ?? ""
        ret["identifier"] = objectID.URIRepresentation()
        ret["content"] = content ?? ""
        ret["read"] = read
        ret["flags"] = allFlags()
        ret["id"] = self.objectID.description
        return ret
    }
}