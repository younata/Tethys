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
            loadingBar.progress = 0
        }
    }
    
    let nameLabel = UILabel(forAutoLayout: ())
    let loadingBar = UIProgressView(progressViewStyle: .Default)
    
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
        nameLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: loadingBar, withOffset: 8)
    }
}
