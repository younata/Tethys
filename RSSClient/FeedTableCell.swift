//
//  FeedTableCell.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/29/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class FeedTableCell: UITableViewCell {
    
    var feed: Feed? = nil {
        didSet {
            if let f = feed {
                let title = f.allTags().reduce(f.title) {
                    if $1.hasPrefix("~") { return $1.substringFromIndex($1.startIndex) }; return $0
                }
                nameLabel.text = f.title
                summaryLabel.text = f.summary
                unreadCounter.unread = UInt(filter(f.articles.allObjects, {return $0.read == false}).count)
            } else {
                nameLabel.text = ""
                summaryLabel.text = ""
                unreadCounter.unread = 0
            }
        }
    }
    
    let nameLabel = UILabel(forAutoLayout: ())
    let summaryLabel = UILabel(forAutoLayout: ())
    let unreadCounter = UnreadCounter(frame: CGRectZero)
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        unreadCounter.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        self.contentView.addSubview(nameLabel)
        self.contentView.addSubview(summaryLabel)
        self.contentView.addSubview(unreadCounter)
        
        unreadCounter.autoPinEdgeToSuperviewEdge(.Top)
        unreadCounter.autoPinEdgeToSuperviewEdge(.Right)
        unreadCounter.autoSetDimension(.Height, toSize: 45)
        unreadCounter.autoMatchDimension(.Width, toDimension: .Height, ofView: unreadCounter)
        unreadCounter.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 0, relation: .GreaterThanOrEqual)
        
        nameLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        nameLabel.autoPinEdge(.Right, toEdge: .Left, ofView: unreadCounter, withOffset: -8)
        nameLabel.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        
        nameLabel.numberOfLines = 0
        nameLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        
        summaryLabel.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4)
        summaryLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        summaryLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: nameLabel, withOffset: 8, relation: .GreaterThanOrEqual)
        summaryLabel.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        
        summaryLabel.numberOfLines = 0
        summaryLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
}
