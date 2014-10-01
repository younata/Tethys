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
                    iconWidth?.constant = image.size.width
                    iconHeight?.constant = image.size.height
                }
                
                nameLabel.text = f.title
                summaryLabel.text = f.summary
            } else {
                iconView.image = nil
                iconWidth?.constant = 0
                iconHeight?.constant = 0
                nameLabel.text = ""
            }
        }
    }
    
    let nameLabel = UILabel(forAutoLayout: ())
    let iconView = UIImageView(forAutoLayout: ())
    let summaryLabel = UILabel(forAutoLayout: ())
    
    var iconHeight : NSLayoutConstraint? = nil
    var iconWidth : NSLayoutConstraint? = nil
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubview(nameLabel)
        self.contentView.addSubview(iconView)
        self.contentView.addSubview(summaryLabel)
        
        iconView.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        iconView.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        iconView.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4, relation: .GreaterThanOrEqual)
        iconHeight = iconView.autoSetDimension(.Height, toSize: 0)
        iconWidth = iconView.autoSetDimension(.Width, toSize: 0)
        
        nameLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        nameLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        nameLabel.autoPinEdge(.Left, toEdge: .Right, ofView: iconView, withOffset: 8)
        nameLabel.numberOfLines = 0
        nameLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        
        summaryLabel.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4)
        summaryLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        summaryLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: nameLabel, withOffset: 8, relation: .GreaterThanOrEqual)
        summaryLabel.autoPinEdge(.Left, toEdge: .Right, ofView: iconView, withOffset: 8)
        summaryLabel.numberOfLines = 0
        summaryLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
}
