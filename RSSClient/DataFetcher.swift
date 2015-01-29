//
//  DataFetcher.swift
//  RSSClient
//
//  Created by Rachel Brindle on 1/26/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation

class DataFetcher {
    
    lazy var mainManager : Manager = {
        let manager = Manager(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        manager.session.configuration.timeoutIntervalForRequest = 30.0;
        manager.session.configuration.timeoutIntervalForResource = 30.0;
        return manager
    }()
    
    lazy var backgroundManager : Manager = {
        let manager = Manager(configuration: NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("com.rachelbrindle.rNews.background"))
        manager.session.configuration.timeoutIntervalForRequest = 30.0;
        manager.session.configuration.timeoutIntervalForResource = 30.0;
        return manager
    }()
    
    let unknownError = NSError(domain: "com.rachelbrindle.rssclient", code: 1, userInfo: ["description": "Unknown Error"])
    let conversionStringError = NSError(domain: "com.rachelbrindle.rssclient", code: 11, userInfo: ["description": "Error Converting data to string"])
    let conversionImageError = NSError(domain: "com.rachelbrindle.rssclient", code: 12, userInfo: ["description": "Error Converting data to image"])
    
    func fetchItemAtURL(url: String, completionHandler: (NSData?, NSError?) -> (Void)) -> Request {
        return fetchItemAtURL(url, background: false, completionHandler: completionHandler)
    }
    
    func fetchItemAtURL(url: String, background: Bool, completionHandler: (NSData?, NSError?) -> (Void)) -> Request {
        let manager = background ? backgroundManager : mainManager
        
        return manager.request(.GET, url).response {(req, response, data, error) in
            if let err = error {
                completionHandler(nil, err)
            } else if let d = data as? NSData {
                completionHandler(d, nil)
            } else {
                completionHandler(nil, self.unknownError) // FIXME
            }
        }
    }
    
    func fetchFeedAtURL(url: String, background: Bool = false, completionHandler: (String?, NSError?) -> (Void)) -> Request {
        return fetchItemAtURL(url, background: background) {(data, error) in
            if let err = error {
                completionHandler(nil, err)
            } else if let d = data {
                if let str = NSString(data: d, encoding: NSUTF8StringEncoding) {
                    completionHandler(str, nil)
                } else {
                    completionHandler(nil, self.conversionStringError)
                }
            } else {
                completionHandler(nil, self.unknownError) // FIXME
            }
        }
    }
    
    func fetchImageAtURL(url: String, completionHandler: (Image?, NSError?) -> (Void)) -> Request {
        return fetchItemAtURL(url) {(data, error) in
            if let err = error {
                completionHandler(nil, error)
            } else if let d = data {
                if let image = Image(data: d) {
                    completionHandler(image, nil)
                } else {
                    completionHandler(nil, self.conversionImageError)
                }
            } else {
                completionHandler(nil, self.unknownError)
            }
        }
    }
}