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
            // TODO: enclosures.
            let hasNotRead = article?.read != true
            unread.unread = hasNotRead ? 1 : 0
            unreadWidth.constant = (hasNotRead ? 30 : 0)
            if article?.enclosures != nil && article?.enclosures.count != 0 {
                enclosures.text = NSString.localizedStringWithFormat(NSLocalizedString("%ld enclosures", comment: ""), article!.enclosures.count)
            } else {
                enclosures.text = ""
            }
        }
    }
    
    let title = UILabel(forAutoLayout: ())
    let published = UILabel(forAutoLayout: ())
    let author = UILabel(forAutoLayout: ())
    let unread = UnreadCounter(frame: CGRectZero)
    
    let enclosures = UILabel(forAutoLayout: ())
    
    var unreadWidth: NSLayoutConstraint! = nil
    
    let dateFormatter = NSDateFormatter()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        unread.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        self.contentView.addSubview(title)
        self.contentView.addSubview(author)
        self.contentView.addSubview(published)
        self.contentView.addSubview(unread)
        self.contentView.addSubview(enclosures)
        
        title.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        title.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        
        title.numberOfLines = 0
        title.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        
        author.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        author.autoPinEdge(.Top, toEdge: .Bottom, ofView: title, withOffset: 8)
        author.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4)
        
        author.numberOfLines = 0
        author.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        
        unread.autoPinEdgeToSuperviewEdge(.Top)
        unread.autoPinEdgeToSuperviewEdge(.Right)
        unread.autoSetDimension(.Height, toSize: 30)
        unreadWidth = unread.autoSetDimension(.Width, toSize: 30)
        
        unread.hideUnreadText = true
        
        published.autoPinEdge(.Right, toEdge: .Left, ofView: unread, withOffset: -8)
        published.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        published.autoPinEdge(.Left, toEdge: .Right, ofView: title, withOffset: 8)
        published.autoMatchDimension(.Width, toDimension: .Width, ofView: published.superview, withMultiplier: 0.25)
        
        enclosures.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        enclosures.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4)
        enclosures.autoPinEdge(.Top, toEdge: .Bottom, ofView: unread, withOffset: 8)
        enclosures.autoPinEdge(.Left, toEdge: .Right, ofView: author, withOffset: 8)
        
        published.textAlignment = .Right
        published.numberOfLines = 0
        published.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        
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
