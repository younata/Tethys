import UIKit
import WebKit
import rNewsKit

public class ArticleCell: UITableViewCell {
    public var article: Article? {
        didSet {
            self.title.text = self.article?.title ?? ""
            let publishedDate = self.article?.updatedAt ?? self.article?.published ?? NSDate()
            self.published.text = self.dateFormatter.stringFromDate(publishedDate) ?? ""
            self.author.text = self.article?.author ?? ""
            let hasNotRead = self.article?.read != true
            self.unread.unread = hasNotRead ? 1 : 0
            self.unreadWidth.constant = (hasNotRead ? 30 : 0)
            if let readingTime = self.article?.estimatedReadingTime where readingTime > 0 {
                self.readingTime.hidden = false
                let localizedFormat = NSLocalizedString("ArticleCell_EstimatedReadingTime", comment: "")
                let formattedTime = self.timeFormatter.stringFromTimeInterval(NSTimeInterval(readingTime * 60)) ?? ""
                self.readingTime.text = NSString.localizedStringWithFormat(localizedFormat, formattedTime) as String
            } else {
                self.readingTime.hidden = true
                self.readingTime.text = nil
            }
        }
    }

    public let title = UILabel(forAutoLayout: ())
    public let published = UILabel(forAutoLayout: ())
    public let author = UILabel(forAutoLayout: ())
    public let unread = UnreadCounter(forAutoLayout: ())
    public let readingTime = UILabel(forAutoLayout: ())

    public var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    private var unreadWidth: NSLayoutConstraint! = nil

    private let dateFormatter: NSDateFormatter = {
        let dateFormatter = NSDateFormatter()

        dateFormatter.timeStyle = .NoStyle
        dateFormatter.dateStyle = .ShortStyle
        dateFormatter.timeZone = NSCalendar.currentCalendar().timeZone

        return dateFormatter
    }()

    private let timeFormatter: NSDateComponentsFormatter = {
        let formatter = NSDateComponentsFormatter()
        formatter.allowedUnits = [.Hour, .Minute]
        formatter.unitsStyle = .Full
        return formatter
    }()

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(self.title)
        self.contentView.addSubview(self.author)
        self.contentView.addSubview(self.published)
        self.contentView.addSubview(self.unread)
        self.contentView.addSubview(self.readingTime)

        self.title.numberOfLines = 0
        self.title.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)

        self.title.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        self.title.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)

        self.author.numberOfLines = 0
        self.author.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)

        self.author.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        self.author.autoPinEdge(.Top, toEdge: .Bottom, ofView: self.title, withOffset: 8)

        self.readingTime.numberOfLines = 0
        self.readingTime.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)

        self.readingTime.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(0, 8, 4, 4), excludingEdge: .Top)
        self.readingTime.autoPinEdge(.Top, toEdge: .Bottom, ofView: self.author, withOffset: 4)

        self.unread.hideUnreadText = true

        self.unread.autoPinEdgeToSuperviewEdge(.Top)
        self.unread.autoPinEdgeToSuperviewEdge(.Right)
        self.unread.autoSetDimension(.Height, toSize: 30)
        self.unreadWidth = unread.autoSetDimension(.Width, toSize: 30)

        self.published.textAlignment = .Right
        self.published.numberOfLines = 0
        self.published.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)

        self.published.autoPinEdge(.Right, toEdge: .Left, ofView: unread, withOffset: -8)
        self.published.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        self.published.autoPinEdge(.Left, toEdge: .Right, ofView: title, withOffset: 8)
        self.published.autoMatchDimension(.Width, toDimension: .Width,
            ofView: self.contentView, withMultiplier: 0.25)
    }

    public required init(coder aDecoder: NSCoder) { fatalError() }
}

extension ArticleCell: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.title.textColor = themeRepository.textColor
        self.published.textColor = themeRepository.textColor
        self.author.textColor = themeRepository.textColor
        self.readingTime.textColor = themeRepository.textColor

        self.backgroundColor = themeRepository.backgroundColor
    }
}
