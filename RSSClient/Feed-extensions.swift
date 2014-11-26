//
//  Feed-extensions.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/26/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation

extension Feed {
    func allArticles(dataManager: DataManager?) -> [Article] {
        if let query = self.query {
            if let dm = dataManager {
                
            }
        } else {
            return self.articles.allObjects as [Article]
        }
        return []
    }
}