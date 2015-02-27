//
//  FeedParser.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/14/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation

func parseFeed(url: NSURL, completion: (MWFeedInfo, [MWFeedItem]) -> Void = {(_, _) in }) -> FeedParser {
    let ret = FeedParser(URL: url).success(completion)
    ret.parse()
    return ret
}

class FeedParser: NSObject, MWFeedParserDelegate {
    var parseInfoOnly : Bool = false
    
    var info : MWFeedInfo? = nil
    var items : [MWFeedItem] = []
    
    var completion : (MWFeedInfo, [MWFeedItem]) -> Void = {(_, _) in }
    var onFailure : (NSError) -> Void = {(_) in }
    
    let feedParser : MWFeedParser
    
    func success(onSuccess: (MWFeedInfo, [MWFeedItem]) -> Void) -> FeedParser {
        completion = onSuccess
        return self
    }
    
    func failure(failed: (NSError) -> Void) -> FeedParser {
        onFailure = failed
        return self
    }
    
    init(URL: NSURL) {
        if URL.scheme == "file://" {
            let contents : String = NSString(contentsOfURL: URL, encoding: NSUTF8StringEncoding, error: nil)!
            feedParser = MWFeedParser(string: contents)
        } else {
            feedParser = MWFeedParser(feedURL: URL)
            feedParser.connectionType = ConnectionTypeAsynchronously
        }
        super.init()
        feedParser.delegate = self
    }
    
    init(string: String) {
        feedParser = MWFeedParser(string: string)
        super.init()
        feedParser.delegate = self
    }
    
    func stopParsing() {
        feedParser.stopParsing()
    }
    
    func parse() {
        feedParser.feedParseType = parseInfoOnly ? ParseTypeInfoOnly : ParseTypeFull
        let queue = NSOperationQueue.currentQueue() ?? NSOperationQueue.mainQueue()
        queue.addOperationWithBlock {
            self.feedParser.parse()
            return
        }
    }
    
    func feedParser(parser: MWFeedParser!, didFailWithError error: NSError!) {
        onFailure(error)
    }
    
    func feedParser(parser: MWFeedParser!, didParseFeedInfo info: MWFeedInfo!) {
        self.info = info
        if parseInfoOnly {
            parser.stopParsing()
        }
    }
    
    func feedParser(parser: MWFeedParser!, didParseFeedItem item: MWFeedItem!) {
        self.items.append(item)
    }
    
    func feedParserDidFinish(parser: MWFeedParser!) {
        if let i = info {
            dispatch_async(dispatch_get_main_queue()) {
                self.completion(i, self.items)
            }
        }
    }
}
