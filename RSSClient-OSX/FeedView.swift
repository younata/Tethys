//
//  FeedView.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/22/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Cocoa

class FeedView: NSTableRowView {
    var feed: Feed? = nil {
        didSet {
            if let f = feed {
                nameLabel.string = f.feedTitle()
                let font : NSFont = nameLabel.font!
                nameHeight?.constant = ceil(NSAttributedString(string: nameLabel.string!, attributes: [NSFontAttributeName: font]).size.height)
                summaryLabel.string = f.feedSummary() ?? ""
                unreadCounter.unread = UInt(filter(f.allArticles(dataManager!), {return $0.read == false}).count)
            } else {
                nameLabel.string = ""
                summaryLabel.string = ""
                unreadCounter.unread = 0
            }
        }
    }
    
    let nameLabel = NSTextView(forAutoLayout: ())
    let summaryLabel = NSTextView(forAutoLayout: ())
    let unreadCounter = UnreadCounter()
    
    var nameHeight : NSLayoutConstraint? = nil
    
    var dataManager: DataManager? = nil
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        
        self.addSubview(nameLabel)
        self.addSubview(summaryLabel)
        self.addSubview(unreadCounter)
        unreadCounter.translatesAutoresizingMaskIntoConstraints = false
        
        unreadCounter.autoPinEdgeToSuperviewEdge(.Top)
        unreadCounter.autoPinEdgeToSuperviewEdge(.Right)
        unreadCounter.autoSetDimensionsToSize(CGSizeMake(30, 30))
        unreadCounter.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 0, relation: .GreaterThanOrEqual)
        
        nameLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        nameLabel.autoPinEdge(.Right, toEdge: .Left, ofView: unreadCounter, withOffset: -8)
        nameLabel.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        nameHeight = nameLabel.autoSetDimension(.Height, toSize: 22)
        
        summaryLabel.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4)
        summaryLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        summaryLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: nameLabel, withOffset: 8, relation: .GreaterThanOrEqual)
        summaryLabel.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        
        for textView in [nameLabel, summaryLabel] {
            textView.textContainerInset = NSMakeSize(0, 0)
            textView.editable = false
            textView.font = NSFont.systemFontOfSize(12)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
