//
//  FeedView.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/22/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Cocoa

class FeedView: NSView {
    var feed: Feed? = nil {
        didSet {
            if let f = feed {
            } else {
                
            }
        }
    }
    
    let nameLabel = NSTextView(forAutoLayout: ())
    let summaryLabel = NSTextView(forAutoLayout: ())
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        
        self.addSubview(nameLabel)
        self.addSubview(summaryLabel)
        
        nameLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
