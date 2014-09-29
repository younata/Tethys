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
            title.text = article?.title
            published.text = dateFormatter.stringFromDate(article?.updatedAt ?? article?.published ?? NSDate())
            author.text = article?.author
            content.loadHTMLString(article?.content ?? article?.summary ?? "", baseURL: NSURL(string: article?.link ?? ""))
            // TODO: enclosures.
            self.highlighted = article?.read ?? false
        }
    }
    
    let title = UILabel(forAutoLayout: ())
    let published = UILabel(forAutoLayout: ())
    let author = UILabel(forAutoLayout: ())
    let content = WKWebView(forAutoLayout: ())
    
    let dateFormatter = NSDateFormatter()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubview(title)
        self.contentView.addSubview(author)
        self.contentView.addSubview(published)
        self.contentView.addSubview(content)
        
        title.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        title.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        title.numberOfLines = 0
        
        author.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        author.autoPinEdge(.Top, toEdge: .Bottom, ofView: title, withOffset: 8)
        author.font = UIFont.systemFontOfSize(15)
        author.autoPinEdge(.Right, toEdge: .Right, ofView: title)
        
        published.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        published.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        published.autoPinEdge(.Left, toEdge: .Right, ofView: title, withOffset: 8)
        published.autoPinEdge(.Bottom, toEdge: .Bottom, ofView: author)
        published.autoMatchDimension(.Width, toDimension: .Width, ofView: published.superview, withMultiplier: 0.25)
        published.textAlignment = .Right
        published.numberOfLines = 0
        published.font = UIFont.systemFontOfSize(15)
        
        content.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(0, 8, 4, 8), excludingEdge: .Top)
        content.autoPinEdge(.Top, toEdge: .Bottom, ofView: published, withOffset: 8)
        
        dateFormatter.timeStyle = .ShortStyle
        dateFormatter.dateStyle = .ShortStyle
        dateFormatter.timeZone = NSCalendar.currentCalendar().timeZone
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("")
    }
}
