import TethysKit

public protocol ArticleCellController {
    func configure(cell: ArticleCell, with article: Article)
}

public struct DefaultArticleCellController: ArticleCellController {
    private let hideUnread: Bool
    private let articleService: ArticleService
    private let settingsRepository: SettingsRepository

    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()

        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .short
        dateFormatter.timeZone = NSCalendar.current.timeZone

        return dateFormatter
    }()

    public init(hideUnread: Bool, articleService: ArticleService, settingsRepository: SettingsRepository) {
        self.hideUnread = hideUnread
        self.articleService = articleService
        self.settingsRepository = settingsRepository
    }

    public func configure(cell: ArticleCell, with article: Article) {
        cell.title.text = article.title
        cell.published.text = self.dateFormatter.string(from: self.articleService.date(for: article))
        cell.author.text = self.articleService.authors(of: article)

        var accessibilityValueItems: [String] = [article.title]

        if self.hideUnread {
            cell.unread.unread = 0
            cell.unreadWidth.constant = 0
            cell.unread.isHidden = true
            cell.accessibilityValue = article.title
        } else {
            cell.unread.unread = article.read ? 0 : 1
            cell.unreadWidth.constant = article.read ? 0 : 30
            cell.unread.isHidden = article.read
            let readString = article.read ?
                NSLocalizedString("ArticleCell_Accessibility_Value_Read", comment: "") :
                NSLocalizedString("ArticleCell_Accessibility_Value_Unread", comment: "")
            accessibilityValueItems.append(readString)
        }

        if self.settingsRepository.showEstimatedReadingLabel {
            cell.readingTime.isHidden = false
            let readingSeconds = self.articleService.estimatedReadingTime(of: article)
            let readingTimeText = String.localizedStringWithFormat(
                NSLocalizedString("ArticleCell_EstimatedReadingTime", comment: ""),
                Int(round(readingSeconds / 60))
            )
            cell.readingTime.text = readingTimeText
            accessibilityValueItems.append(readingTimeText)
        } else {
            cell.readingTime.isHidden = true
            cell.readingTime.text = nil
        }
        cell.accessibilityValue = accessibilityValueItems.joined(separator: ", ")
    }
}
