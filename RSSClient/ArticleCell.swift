//
//  ArticleCell.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit
import WebKit

class ArticleCell: UITableViewCell, UITextViewDelegate {
    
    var article: Article? {
        didSet {
            title.text = article?.title ?? ""
            published.text = article != nil ? dateFormatter.stringFromDate(article?.updatedAt ?? article?.published ?? NSDate()) : ""
            author.text = article?.author ?? ""
            var cnt = article?.summary ?? ""
            
            let data = cnt.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            let options = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType]
            
            let astr = NSAttributedString(data: data, options: options, documentAttributes: nil, error: nil)!
            let bounding = astr.boundingRectWithSize(CGSizeMake(self.contentView.bounds.size.width - 16, CGFloat.max), options: .UsesFontLeading, context: nil)
            contentHeight.constant = ceil(bounding.size.height)
            content.attributedText = astr
            // TODO: enclosures.
            unread.unread = article?.read == false ? 1 : 0
            let width = CGRectGetWidth(unread.bounds)
            unreadWidth.constant = unread.unread == 0 ? -width : 0
        }
    }
    
    let title = UILabel(forAutoLayout: ())
    let published = UILabel(forAutoLayout: ())
    let author = UILabel(forAutoLayout: ())
    let content = UITextView(forAutoLayout: ())
    let unread = UnreadCounter(frame: CGRectZero)
    
    var unreadWidth: NSLayoutConstraint! = nil
    var contentHeight: NSLayoutConstraint! = nil
    
    let dateFormatter = NSDateFormatter()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        unread.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        self.contentView.addSubview(title)
        self.contentView.addSubview(author)
        self.contentView.addSubview(published)
        self.contentView.addSubview(content)
        self.contentView.addSubview(unread)
        
        content.scrollEnabled = false
        content.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        content.textContainerInset = UIEdgeInsetsZero
        content.delegate = self
        
        title.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        title.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        
        title.numberOfLines = 0
        title.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        
        author.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        author.autoPinEdge(.Top, toEdge: .Bottom, ofView: title, withOffset: 8)
        author.autoPinEdge(.Right, toEdge: .Right, ofView: title)
        
        author.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        
        unread.autoPinEdgeToSuperviewEdge(.Top)
        unread.autoPinEdgeToSuperviewEdge(.Right)
        unread.autoSetDimension(.Height, toSize: 30)
        unreadWidth = unread.autoMatchDimension(.Width, toDimension: .Height, ofView: unread)
        
        unread.hideUnreadText = true
        
        published.autoPinEdge(.Right, toEdge: .Left, ofView: unread, withOffset: -8)
        published.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        published.autoPinEdge(.Left, toEdge: .Right, ofView: title, withOffset: 8)
        published.autoPinEdge(.Bottom, toEdge: .Bottom, ofView: author)
        published.autoMatchDimension(.Width, toDimension: .Width, ofView: published.superview, withMultiplier: 0.25)
        
        published.textAlignment = .Right
        published.numberOfLines = 0
        published.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        
        content.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(0, 8, 4, 8), excludingEdge: .Top)
        content.autoPinEdge(.Top, toEdge: .Bottom, ofView: published, withOffset: 8)
        contentHeight = content.autoSetDimension(.Height, toSize: 0)
        
        dateFormatter.timeStyle = .NoStyle
        dateFormatter.dateStyle = .ShortStyle
        dateFormatter.timeZone = NSCalendar.currentCalendar().timeZone
    }
    
    func textView(textView: UITextView, shouldInteractWithURL URL: NSURL, inRange characterRange: NSRange) -> Bool {
        return false
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("")
    }
}
