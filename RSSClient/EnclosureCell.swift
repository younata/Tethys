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
            nameHeight?.constant = ceil(size.height)
            progressLayer.progress = 0
            
            placeholderLabel.text = enclosure?.url.pathExtension ?? ""
        }
    }
    
    let nameLabel = UILabel(forAutoLayout: ())
    let loadingBar = UIView(forAutoLayout: ())
    let progressLayer = CircularProgressLayer()
    
    let placeholderLabel = UILabel(forAutoLayout: ())
    
    var nameHeight : NSLayoutConstraint? = nil
    
    required init(coder: NSCoder) {
        fatalError("")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // FIXME: replace with circular progressview.
        self.contentView.addSubview(loadingBar)
        loadingBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(4, 4, 0, 4), excludingEdge: .Bottom)
        loadingBar.autoSetDimension(.Width, toSize: 60)
        loadingBar.autoMatchDimension(.Height, toDimension: .Width, ofView: loadingBar)
        loadingBar.layer.addSublayer(progressLayer)
        loadingBar.backgroundColor = UIColor.lightGrayColor()
        progressLayer.strokeColor = UIColor.clearColor().CGColor
        progressLayer.fillColor = UIColor.blackColor().colorWithAlphaComponent(0.5).CGColor
        
        loadingBar.addSubview(placeholderLabel)
        placeholderLabel.autoCenterInSuperview()
        placeholderLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        
        self.contentView.addSubview(nameLabel)
        nameLabel.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(0, 4, 4, 4), excludingEdge: .Top)
        nameHeight = nameLabel.autoSetDimension(.Height, toSize: 30)
        nameLabel.autoSetDimension(.Width, toSize: 60)
        nameLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: loadingBar, withOffset: 8)
        nameLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
    }
}
