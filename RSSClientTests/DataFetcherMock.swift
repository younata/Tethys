//
//  DataFetcherMock.swift
//  RSSClient
//
//  Created by pivotal on 1/29/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation

class DataFetcherMock : DataFetcher {
    override func fetchItemAtURL(url: String, background: Bool, completionHandler: (NSData?, NSError?) -> (Void)) -> Request {
        completionHandler(nil, nil)
        return request(.GET, "")
    }

    override func fetchFeedAtURL(url: String, background: Bool, completionHandler: (String?, NSError?) -> (Void)) -> Request {
        return fetchItemAtURL(url, background: background) {(_, _) in completionHandler(nil, nil) }
    }

    override func fetchImageAtURL(url: String, completionHandler: (Image?, NSError?) -> (Void)) -> Request {
        return fetchItemAtURL(url, background: false) {(_, _) in completionHandler(nil, nil) }
    }
}