import UIKit
import TethysKit

public final class ArticleCell: UITableViewCell {
    public let title = UILabel(forAutoLayout: ())
    public let published = UILabel(forAutoLayout: ())
    public let author = UILabel(forAutoLayout: ())
    public let unread = UnreadCounter(forAutoLayout: ())
    public let readingTime = UILabel(forAutoLayout: ())

    public var titleText: String? { return self.title.text }
    public var authorText: String? { return self.author.text }
    public private(set) var publishedDate: Date?
    public private(set) var readingTimeInMinutes: Int?

    public var hideUnread: Bool = false {
        didSet {
            if self.hideUnread {
                self.unread.unread = 0
            }
        }
    }

    public var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    private var unreadWidth: NSLayoutConstraint! = nil

    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()

        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .short
        dateFormatter.timeZone = NSCalendar.current.timeZone

        return dateFormatter
    }()

    private let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        return formatter
    }()

    fileprivate let backgroundColorView = UIView()

    public func configure(title: String, publishedDate: Date, author: String, read: Bool, readingTime: Int?) {
        self.publishedDate = publishedDate
        self.readingTimeInMinutes = readingTime

        self.title.text = title
        self.published.text = self.dateFormatter.string(from: publishedDate)
        self.author.text = author
        if self.hideUnread {
            self.unread.unread = 0
            self.unreadWidth.constant = 0
        } else {
            self.unread.unread = read ? 0 : 1
            self.unreadWidth.constant = read ? 0 : 30
        }
        if let readingTime = readingTime, readingTime > 0 {
            self.readingTime.isHidden = false
            let localizedFormat = NSLocalizedString("ArticleCell_EstimatedReadingTime", comment: "")
            let formattedTime = self.timeFormatter.string(from: TimeInterval(readingTime * 60)) ?? ""
            self.readingTime.text = String.localizedStringWithFormat(localizedFormat, formattedTime)
        } else {
            self.readingTime.isHidden = true
            self.readingTime.text = nil
        }
    }

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(self.title)
        self.contentView.addSubview(self.author)
        self.contentView.addSubview(self.published)
        self.contentView.addSubview(self.unread)
        self.contentView.addSubview(self.readingTime)

        self.title.numberOfLines = 0
        self.title.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)

        self.title.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        self.title.autoPinEdge(toSuperviewEdge: .top, withInset: 4)

        self.author.numberOfLines = 0
        self.author.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)

        self.author.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        self.author.autoPinEdge(.top, to: .bottom, of: self.title, withOffset: 8)

        self.readingTime.numberOfLines = 0
        self.readingTime.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)

        self.readingTime.autoPinEdge(toSuperviewEdge: .leading, withInset: 8)
        self.readingTime.autoPinEdge(toSuperviewEdge: .bottom, withInset: 4)
        self.readingTime.autoPinEdge(.top, to: .bottom, of: self.author, withOffset: 4)

        self.unread.hideUnreadText = true

        self.unread.autoPinEdge(toSuperviewEdge: .top)
        self.unread.autoPinEdge(toSuperviewEdge: .right)
        self.unread.autoSetDimension(.height, toSize: 30)
        self.unreadWidth = unread.autoSetDimension(.width, toSize: 30)

        self.published.textAlignment = .right
        self.published.numberOfLines = 0
        self.published.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)

        self.published.autoPinEdge(.right, to: .left, of: unread, withOffset: -8)
        self.published.autoPinEdge(toSuperviewEdge: .top, withInset: 4)
        self.published.autoPinEdge(.left, to: .right, of: title, withOffset: 8)
        self.published.autoMatch(.width, to: .width,
            of: self.contentView, withMultiplier: 0.25)

        self.multipleSelectionBackgroundView  = self.backgroundColorView
        self.selectedBackgroundView = self.backgroundColorView
    }

    public required init(coder aDecoder: NSCoder) { fatalError() }
}

extension ArticleCell: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.title.textColor = themeRepository.textColor
        self.published.textColor = themeRepository.textColor
        self.author.textColor = themeRepository.textColor
        self.readingTime.textColor = themeRepository.textColor
        self.backgroundColorView.backgroundColor = themeRepository.textColor.withAlphaComponent(0.3)

        self.backgroundColor = themeRepository.backgroundColor
    }
}
