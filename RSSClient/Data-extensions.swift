//
//  Data-extensions.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/26/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation

#if os(iOS)
    typealias Image=UIImage
#else
    typealias Image=NSImage
#endif

extension Feed {
    func feedImage() -> Image? {
        if self.image == nil { return nil }
        return (self.image as? Image)
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
        if let articles = self.articles as? Set<Article> {
            return Array<Article>(articles)
        }
        return []
    }
    
    func allArticles(dataManager: DataManager) -> [Article] {
        if let query = self.query {
            return dataManager.articlesMatchingQuery(query, feed: self)
        } else {
            return self.allArticles()
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
        if let tags = self.tags as? [String] {
            return tags
        }
        return []
    }
    
    func asDict() -> [String: AnyObject] {
        var ret = asDictNoArticles()
        var theArticles : [[String: AnyObject]] = []
        if let articles = self.articles as? Set<Article> {
            for article in Array<Article>(articles) {
                theArticles.append(article.asDictNoFeed())
            }
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
        if let flags = self.flags as? [String] {
            return flags
        }
        return []
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