//
//  ArticleListView.swift
//  RSSClient
//
//  Created by Rachel Brindle on 12/16/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Cocoa

class ArticleListView: NSTableRowView {
    var article: Article? = nil {
        didSet {
            if let a = article {
                title.string = a.title ?? ""
                let date = a.updatedAt ?? a.published
                published.string = (date == nil ? "" : dateFormatter.stringFromDate(a.updatedAt ?? a.published))
                author.string = a.author ?? ""
                
                let hasNotRead = a.read != true
                unread.unread = (hasNotRead ? 1 : 0)
                unreadWidth?.constant = (hasNotRead ? 20 : 0)
            } else {
                title.string = ""
                published.string = ""
                author.string = ""
                unread.unread = 0
            }
        }
    }
    
    let title = NSTextView(forAutoLayout: ())
    let published = NSTextView(forAutoLayout: ())
    let author = NSTextView(forAutoLayout: ())
    let unread = UnreadCounter()
    
    var unreadWidth: NSLayoutConstraint? = nil
    var titleHeight : NSLayoutConstraint? = nil
    var authorHeight : NSLayoutConstraint? = nil
    
    let dateFormatter = NSDateFormatter()
    
    override func layout() {
        titleHeight?.constant = ceil(NSAttributedString(string: title.string!, attributes: [NSFontAttributeName: title.font!]).size.height)
        //authorHeight?.constant = ceil(NSAttributedString(string: author.string!, attributes: [NSFontAttributeName: author.font!]).size.height)
        
        super.layout()
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        
        unread.translatesAutoresizingMaskIntoConstraints = false
        
        self.addSubview(title)
        self.addSubview(author)
        self.addSubview(published)
        self.addSubview(unread)
        
        title.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        title.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        titleHeight = title.autoSetDimension(.Height, toSize: 18)
        title.font = NSFont.systemFontOfSize(14)
        
        author.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        author.autoPinEdge(.Top, toEdge: .Bottom, ofView: title, withOffset: 8)
        author.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4)
        //authorHeight = author.autoSetDimension(.Height, toSize: 16)
        author.font = NSFont.systemFontOfSize(12)
        
        unread.autoPinEdgeToSuperviewEdge(.Top)
        unread.autoPinEdgeToSuperviewEdge(.Right)
        unread.autoSetDimension(.Height, toSize: 20)
        unreadWidth = unread.autoSetDimension(.Width, toSize: 20)
        unread.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 0, relation: .GreaterThanOrEqual)
        
        unread.hideUnreadText = true
        
        published.autoPinEdge(.Right, toEdge: .Left, ofView: unread, withOffset: -8)
        published.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        published.autoPinEdge(.Left, toEdge: .Right, ofView: title, withOffset: 8)
        published.autoMatchDimension(.Width, toDimension: .Width, ofView: published.superview, withMultiplier: 0.25)
        
        dateFormatter.timeStyle = .NoStyle
        dateFormatter.dateStyle = .ShortStyle
        dateFormatter.timeZone = NSCalendar.currentCalendar().timeZone
        
        for tv in [title, author, published] {
            tv.textContainerInset = NSMakeSize(0, 0)
            tv.editable = false
        }
        published.font = NSFont.systemFontOfSize(12)
        published.alignment = .RightTextAlignment
    }
    
    required init?(coder: NSCoder) {
        fatalError("")
    }
}
