//
//  EnclosureCell.swift
//  RSSClient
//
//  Created by Rachel Brindle on 12/4/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class EnclosureCell: UICollectionViewCell {
    var enclosure: Enclosure? = nil {
        didSet {
            nameLabel.text = enclosure?.url.lastPathComponent ?? ""
            let size = NSAttributedString(string: nameLabel.text!, attributes: [NSFontAttributeName: nameLabel.font]).boundingRectWithSize(CGSizeMake(120, CGFloat.max), options: .UsesFontLeading, context: nil).size
            nameWidth?.constant = ceil(size.width)
            nameHeight?.constant = ceil(size.height)
            loadingBar.progress = 0
        }
    }
    
    let nameLabel = UILabel(forAutoLayout: ())
    let loadingBar = UIProgressView(progressViewStyle: .Default)
    
    var nameWidth : NSLayoutConstraint? = nil
    var nameHeight : NSLayoutConstraint? = nil
    
    required init(coder: NSCoder) {
        fatalError("")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // FIXME: replace with circular progressview.
        self.contentView.addSubview(loadingBar)
        loadingBar.progressTintColor = UIColor.darkGreenColor()
        loadingBar.trackTintColor = UIColor.clearColor()
        loadingBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(4, 4, 0, 4), excludingEdge: .Bottom)
        loadingBar.autoSetDimension(.Height, toSize: 1)
        
        self.contentView.addSubview(nameLabel)
        nameLabel.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(0, 4, 4, 4), excludingEdge: .Top)
        nameHeight = nameLabel.autoSetDimension(.Height, toSize: 30)
        nameWidth = nameLabel.autoSetDimension(.Width, toSize: 120)
        nameLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: loadingBar, withOffset: 8)
        nameLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
    }
}
