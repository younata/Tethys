//
//  FeedCell.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class FeedCell: UICollectionViewCell, RSBDragMenuDelegate {
    var image: UIImage? {
        didSet {
            imageView.image = image
            if let i = image {
                imageWidth?.constant = i.size.width
                imageHeight?.constant = i.size.height
            } else {
                imageWidth?.constant = 0
                imageHeight?.constant = 0
            }
        }
    }
    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }
    var summary: String? {
        didSet {
            summaryLabel.text = summary
        }
    }
    var link : NSURL?
    
    weak var controller: AllFeedsViewController?
    
    private let imageView = UIImageView(forAutoLayout: ())
    private let titleLabel = UILabel(forAutoLayout: ())
    private let summaryLabel = UILabel(forAutoLayout: ())
    private let dragMenu = RSBDragMenu(forAutoLayout: ())
    
    private var imageWidth: NSLayoutConstraint? = nil
    private var imageHeight: NSLayoutConstraint? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.contentView.addSubview(imageView)
        self.contentView.addSubview(titleLabel)
        self.contentView.addSubview(summaryLabel)
        self.contentView.addSubview(dragMenu)
        
        imageView.autoPinEdgeToSuperviewEdge(.Left, withInset: 0)
        imageView.autoPinEdgeToSuperviewEdge(.Top, withInset: 0)
        imageView.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 0, relation: .GreaterThanOrEqual)
        if (image != nil) {
            imageWidth = self.imageView.autoSetDimension(.Width, toSize: image!.size.width)
            imageHeight = self.imageView.autoSetDimension(.Height, toSize: image!.size.height)
        } else {
            imageWidth = self.imageView.autoSetDimension(.Width, toSize: 0)
            imageHeight = self.imageView.autoSetDimension(.Height, toSize: 0)
        }
        
        titleLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 0)
        titleLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 0)
        titleLabel.autoPinEdge(.Left, toEdge: .Right, ofView: self.imageView, withOffset: 8)
        titleLabel.numberOfLines = 0
        
        summaryLabel.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 0)
        summaryLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 0)
        summaryLabel.autoPinEdge(.Left, toEdge: .Left, ofView: self.titleLabel)
        summaryLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: self.titleLabel, withOffset: 8, relation: .GreaterThanOrEqual)
        summaryLabel.autoSetDimension(.Width, toSize: 280, relation: .LessThanOrEqual)
        summaryLabel.font = UIFont.systemFontOfSize(15)
        summaryLabel.numberOfLines = 0
        
        dragMenu.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        //dragMenu.circularMenu = false
        dragMenu.borderColor = UIColor.blackColor()
        dragMenu.borderWidth = 1
        dragMenu.delegate = self
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
  
    func dragMenu(menu: RSBDragMenu!, didSelectItem item: UIView!) {
        let itemTexts = [NSString.localizedStringWithFormat(NSLocalizedString("Open %@", comment: ""), self.title!),
                         NSString.localizedStringWithFormat(NSLocalizedString("Delete %@", comment: ""), self.title!)]
        let l = (item as UILabel)
        if let c = controller {
            if l.text == itemTexts[0] {
                c.showFeedFromCell(self)
            } else if l.text == itemTexts[1] {
                c.deleteCell(self)
            }
        }
    }
    
    func menuItemsForDragMenu(menu: RSBDragMenu!, atPoint point: CGPoint) -> [AnyObject]! {
        let itemTexts = [NSString.localizedStringWithFormat(NSLocalizedString("Open %@", comment: ""), self.title!),
                         NSString.localizedStringWithFormat(NSLocalizedString("Delete %@", comment: ""), self.title!)]
        let colors = [UIColor.greenColor(), UIColor.redColor()]
        var ret : [UILabel] = []
        let font = UIFont.systemFontOfSize(17)
        for (idx, item) in enumerate(itemTexts) {
            let s = item.boundingRectWithSize(CGSizeMake(120, CGFloat.max), options: .UsesFontLeading, attributes: [NSFontAttributeName: font], context: nil)
            let l = UILabel(frame: CGRectMake(0, 0, ceil(s.width), ceil(s.height)))
            l.text = item
            l.textColor = colors[idx]
            l.numberOfLines = 0
            l.font = font
            ret.append(l)
        }
        return ret
    }
}
