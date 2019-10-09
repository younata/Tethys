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
    private let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        return formatter
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
            cell.accessibilityValue = "\(article.title), \(readString)"
        }

        if self.settingsRepository.showEstimatedReadingLabel {
            cell.readingTime.isHidden = false
            let localizedFormat = NSLocalizedString("ArticleCell_EstimatedReadingTime", comment: "")
            let readingTime = self.articleService.estimatedReadingTime(of: article)
            let formattedTime = self.timeFormatter.string(from: readingTime) ?? ""
            cell.readingTime.text = String.localizedStringWithFormat(localizedFormat, formattedTime)
        } else {
            cell.readingTime.isHidden = true
            cell.readingTime.text = nil
        }
    }
}
