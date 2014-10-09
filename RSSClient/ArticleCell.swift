//
//  ArticleCell.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit
import WebKit

class ArticleCell: UITableViewCell {
    
    var article: Article? {
        didSet {
            title.text = article?.title ?? ""
            published.text = article != nil ? dateFormatter.stringFromDate(article?.updatedAt ?? article?.published ?? NSDate()) : ""
            author.text = article?.author ?? ""
            var cnt = article?.content ?? ""
            if (cnt == nil || cnt?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) == 0) {
                cnt = article?.summary
                if (cnt == nil || cnt?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) == 0) {
                    cnt = ""
                }
            }
            content.loadHTMLString(cnt, baseURL: NSURL(string: article?.link ?? ""))
            let astr = NSAttributedString(string: cnt!, attributes: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                                     NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleBody)])
            let bounding = astr.boundingRectWithSize(CGSizeMake(self.contentView.bounds.size.width - 16, CGFloat.max), options: .UsesFontLeading, context: nil)
            contentHeight.constant = ceil(bounding.size.height)
            //content.attributedText = astr
            // TODO: enclosures.
            unread.unread = article?.read == false ? 1 : 0
            let width = CGRectGetWidth(unread.bounds)
            unreadWidth.constant = unread.unread == 0 ? -width : 0
        }
    }
    
    let title = UILabel(forAutoLayout: ())
    let published = UILabel(forAutoLayout: ())
    let author = UILabel(forAutoLayout: ())
    let content: WKWebView! = nil
    let unread = UnreadCounter(frame: CGRectZero)
    
    var unreadWidth: NSLayoutConstraint! = nil
    var contentHeight: NSLayoutConstraint! = nil
    
    let dateFormatter = NSDateFormatter()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        let config = WKWebViewConfiguration()
        config.preferences.minimumFontSize = 18
        content = WKWebView(frame: CGRectZero, configuration: config)
        
        unread.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        self.contentView.addSubview(title)
        self.contentView.addSubview(author)
        self.contentView.addSubview(published)
        self.contentView.addSubview(content)
        self.contentView.addSubview(unread)
        
        title.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        title.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        
        title.numberOfLines = 0
        title.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        
        author.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        author.autoPinEdge(.Top, toEdge: .Bottom, ofView: title, withOffset: 8)
        author.autoPinEdge(.Right, toEdge: .Right, ofView: title)
        
        author.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        
        unread.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        unread.autoAlignAxis(.Horizontal, toSameAxisOfView: title)
        unread.autoSetDimension(.Height, toSize: 20)
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
    
    required init(coder aDecoder: NSCoder) {
        fatalError("")
    }
}
