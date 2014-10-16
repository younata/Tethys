
//
//  ScriptDocument.swift
//  RSSClient
//
//  Created by Rachel Brindle on 10/15/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

extension String {
}

class ScriptDocument: UIDocument {
    var text : String? = nil {
        didSet {
            // oldValue
            if (notifyUndo) {
                self.undoManager?.registerUndoWithTarget(self, selector: "undo:", object: oldValue)
            }
        }
    }
    
    var notifyUndo = true
    
    func undo(value: String?) {
        notifyUndo = false
        text = value
        notifyUndo = true
    }
    
    override init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "conflict:", name: UIDocumentStateChangedNotification, object: self)
    }
    
    override init(fileURL url: NSURL) {
        super.init(fileURL: url)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "conflict:", name: UIDocumentStateChangedNotification, object: self)
    }
    
    func conflict(note: NSNotification) {
        if self.documentState == .InConflict {
            let docs = NSFileVersion.unresolvedConflictVersionsOfItemAtURL(self.fileURL)
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func contentsForType(typeName: String, error outError: NSErrorPointer) -> AnyObject? {
        return text?.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
    }
    
    override func loadFromContents(contents: AnyObject, ofType typeName: String, error outError: NSErrorPointer) -> Bool {
        if let cnt = contents as? NSData {
            text = NSString(data: cnt, encoding: NSUTF8StringEncoding)
            self.undoManager?.beginUndoGrouping()
            return true
        } else {
            let error = NSError(domain: "com.rachelbrindle.rssclient", code: 404, userInfo: ["reason": "data not stored as NSData"])
            return false
        }
    }
}
