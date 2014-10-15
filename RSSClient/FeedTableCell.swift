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
                if let image: UIImage = f.image as? UIImage {
                    iconView.image = image
                    iconWidth.constant = image.size.width
                    iconHeight.constant = image.size.height
                }
                
                nameLabel.text = f.title
                summaryLabel.text = f.summary
                unreadCounter.unread = UInt(filter(f.articles.allObjects, {return $0.read == false}).count)
            } else {
                iconView.image = nil
                iconWidth.constant = 0
                iconHeight.constant = 0
                nameLabel.text = ""
                summaryLabel.text = ""
                unreadCounter.unread = 0
            }
            let width = CGRectGetWidth(unreadCounter.bounds)
            unreadWidth.constant = unreadCounter.unread == 0 ? -width : 0
        }
    }
    
    let nameLabel = UILabel(forAutoLayout: ())
    let iconView = UIImageView(forAutoLayout: ())
    let summaryLabel = UILabel(forAutoLayout: ())
    let unreadCounter = UnreadCounter(frame: CGRectZero)
    
    var unreadWidth: NSLayoutConstraint! = nil
    var iconHeight : NSLayoutConstraint! = nil
    var iconWidth : NSLayoutConstraint! = nil
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        unreadCounter.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        self.contentView.addSubview(nameLabel)
        self.contentView.addSubview(iconView)
        self.contentView.addSubview(summaryLabel)
        self.contentView.addSubview(unreadCounter)
        
        iconView.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        iconView.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        iconView.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4, relation: .GreaterThanOrEqual)
        iconHeight = iconView.autoSetDimension(.Height, toSize: 0)
        iconWidth = iconView.autoSetDimension(.Width, toSize: 0)
        
        unreadCounter.autoPinEdgeToSuperviewEdge(.Top)
        unreadCounter.autoPinEdgeToSuperviewEdge(.Right)
        unreadCounter.autoSetDimension(.Height, toSize: 45)
        unreadWidth = unreadCounter.autoMatchDimension(.Width, toDimension: .Height, ofView: unreadCounter)
        
        nameLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        nameLabel.autoPinEdge(.Right, toEdge: .Left, ofView: unreadCounter, withOffset: -8)
        nameLabel.autoPinEdge(.Left, toEdge: .Right, ofView: iconView, withOffset: 8)
        
        nameLabel.numberOfLines = 0
        nameLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        
        summaryLabel.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4)
        summaryLabel.autoPinEdge(.Right, toEdge: .Left, ofView: unreadCounter, withOffset: -8)
        summaryLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: nameLabel, withOffset: 8, relation: .GreaterThanOrEqual)
        summaryLabel.autoPinEdge(.Left, toEdge: .Right, ofView: iconView, withOffset: 8)
        
        summaryLabel.numberOfLines = 0
        summaryLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
}
