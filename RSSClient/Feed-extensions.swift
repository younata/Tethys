//
//  Feed-extensions.swift
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
            return dataManager.articlesMatchingQuery(query)
        } else {
            return self.articles.allObjects as [Article]
        }
    }
    
    func allTags() -> [String] {
        return self.tags == nil ? [] : self.tags as [String]
    }
}