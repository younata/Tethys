//
//  OPMLParser.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/8/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation

class OPMLParser : NSObject, NSXMLParserDelegate {

    var callback : ([String]) -> Void = {(_) in }
    
    private var xmlParser : NSXMLParser
    private var items : [String] = []
    private var isOPML = false
    
    init(text: String) {
        xmlParser = NSXMLParser(data: text.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false))
    }
    
    func parse() {
        items = []
        xmlParser.parse()
    }
    
    // MARK: NSXMLParserDelegate
    
    func parserDidEndDocument(parser: NSXMLParser!) {
        if (isOPML) {
            callback(items)
        }
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
            if let url = attributeDict["xmlUrl"] as? String {
                items.append(url)
            }
        }
    }
}