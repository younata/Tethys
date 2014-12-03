//
//  TagCollectionViewCell.swift
//  RSSClient
//
//  Created by Rachel Brindle on 12/2/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class TagCollectionViewCell: UICollectionViewCell {
    let label = UILabel(forAutoLayout: ())
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.addSubview(label)
        label.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("")
    }
}
