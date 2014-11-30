//
//  Data-extensions.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/26/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation

extension Feed {
    func unreadArticles(dataManager: DataManager) -> UInt {
        return allArticles(dataManager).reduce(0) {
            return $0 + ($1.read ? 0 : 1)
        }
    }
    
    func allArticles(dataManager: DataManager) -> [Article] {
        if let query = self.query {
            return dataManager.articlesMatchingQuery(query, feed: self)
        } else {
            return self.articles.allObjects as [Article]
        }
    }
    
    func feedTitle() -> String? {
        return reduce(allTags(), self.title) {
            if $1.hasPrefix("~") {
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
        return ret
    }
}

extension Article {
    func asDict() -> [String: AnyObject] {
        var ret = asDictNoFeed()
        ret["feed"] = feed.asDictNoArticles()
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
        ret["identifier"] = identifier ?? ""
        ret["content"] = content ?? ""
        ret["read"] = read
        return ret
    }
}