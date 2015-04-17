//
//  OPMLParser.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/8/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation

func parseOPML(text: String, success: ([OPMLItem]) -> Void = {(_) in }) -> OPMLParser {
    let ret = OPMLParser(text: text).success(success)
    ret.parse()
    return ret
}

class OPMLItem : NSObject {
    var title : String? = nil
    var summary : String? = nil
    var xmlURL: String? = nil
    var query : String? = nil
    var tags: [String]? = nil
    
    func isValidItem() -> Bool {
        return xmlURL != nil || (query != nil && title != nil)
    }
    
    func isQueryFeed() -> Bool {
        return query != nil
    }
}

class OPMLParser : NSObject, NSXMLParserDelegate {
    var callback : ([OPMLItem]) -> Void = {(_) in }
    var onFailure : (NSError) -> Void = {(_) in }
    
    private var xmlParser : NSXMLParser
    private var items : [OPMLItem] = []
    private var isOPML = false
    
    func success(onSuccess: ([OPMLItem]) -> Void) -> OPMLParser {
        callback = onSuccess
        return self
    }
    
    func failure(failed: (NSError) -> Void) -> OPMLParser {
        onFailure = failed
        return self
    }
    
    init(text: String) {
        xmlParser = NSXMLParser(data: text.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
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
    
    func parserDidEndDocument(parser: NSXMLParser) {
        if (isOPML) {
            callback(items)
        }
    }
    
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        isOPML = false
        println("\(parseError)")
        onFailure(parseError)
    }
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [NSObject : AnyObject]) {
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
            var item = OPMLItem()
            for (k, v) in attributeDict {
                let key = (k as! String).lowercaseString
                let value = v as! String
                if value == "" {
                    continue
                }
                if key == "xmlurl" {
                    item.xmlURL = value
                }
                if key == "tags" {
                    let comps = value.componentsSeparatedByString(",") as [String]
                    item.tags = comps.map({(str: String) in
                        return str.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                    })
                }
                if key == "query" {
                    item.query = value
                }
                if key == "title" {
                    item.title = value
                }
                if key == "summary" || key == "description" {
                    item.summary = value
                }
            }
            if item.isValidItem() {
                items.append(item)
            }
        }
    }
}