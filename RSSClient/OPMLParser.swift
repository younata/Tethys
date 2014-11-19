//
//  OPMLParser.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/8/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation

func parseOPML(text: String, success: ([String]) -> Void = {(_) in }) -> OPMLParser {
    let ret = OPMLParser(text: text).success(success)
    ret.parse()
    return ret
}

class OPMLParser : NSObject, NSXMLParserDelegate {
    var callback : ([String]) -> Void = {(_) in }
    var onFailure : (NSError) -> Void = {(_) in }
    
    private var xmlParser : NSXMLParser
    private var items : [String] = []
    private var isOPML = false
    
    func success(onSuccess: ([String]) -> Void) -> OPMLParser {
        callback = onSuccess
        return self
    }
    
    func failure(failed: (NSError) -> Void) -> OPMLParser {
        onFailure = failed
        return self
    }
    
    init(text: String) {
        xmlParser = NSXMLParser(data: text.lowercaseString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false))
        super.init()
        xmlParser.delegate = self
    }
    
    func parse() {
        items = []
        xmlParser.parse()
    }
    
    func stopParsing() {
        xmlParser.abortParsing()
    }
    
    // MARK: NSXMLParserDelegate
    
    func parserDidEndDocument(parser: NSXMLParser!) {
        if (isOPML) {
            callback(items)
        }
    }
    
    func parser(parser: NSXMLParser!, parseErrorOccurred parseError: NSError!) {
        onFailure(parseError)
    }
    
    func parser(parser: NSXMLParser!, didStartElement elementName: String!, namespaceURI: String!, qualifiedName qName: String!, attributes attributeDict: [NSObject : AnyObject]!) {
        if elementName.lowercaseString == "xml" {
            return
        }
        if elementName.lowercaseString == "opml" {
            isOPML = true
        }
        if (!isOPML) {
            return
        }
        if elementName.lowercaseString.hasPrefix("outline") {
            if let url = attributeDict["xmlurl"] as? String {
                items.append(url)
            }
        }
    }
}