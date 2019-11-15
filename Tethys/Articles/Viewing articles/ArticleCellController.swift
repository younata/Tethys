import TethysKit

public protocol ArticleCellController {
    func configure(cell: ArticleCell, with article: Article)
}

public struct DefaultArticleCellController: ArticleCellController {
    private let hideUnread: Bool
    private let articleCoordinator: ArticleCoordinator
    private let settingsRepository: SettingsRepository

    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()

        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .short
        dateFormatter.timeZone = NSCalendar.current.timeZone

        return dateFormatter
    }()

    public init(hideUnread: Bool, articleCoordinator: ArticleCoordinator, settingsRepository: SettingsRepository) {
        self.hideUnread = hideUnread
        self.articleCoordinator = articleCoordinator
        self.settingsRepository = settingsRepository
    }

    public func configure(cell: ArticleCell, with article: Article) {
        cell.title.text = article.title
        cell.published.text = self.dateFormatter.string(from: self.articleCoordinator.date(for: article))
        cell.author.text = self.articleCoordinator.authors(of: article)

        var accessibilityValueItems: [String] = [article.title]

        if self.hideUnread {
            self.configureCellToHideUnread(cell, article: article)
        } else {
            accessibilityValueItems.append(self.configureCellToShowUnread(cell, article: article))
        }

        if self.settingsRepository.showEstimatedReadingLabel {
            accessibilityValueItems.append(self.configureCellToShowReadingTime(cell, article: article))
        } else {
            self.configureCellToHideReadingTime(cell)
        }
        cell.accessibilityValue = accessibilityValueItems.joined(separator: ", ")
    }

    private func configureCellToHideUnread(_ cell: ArticleCell, article: Article) {
        cell.unread.unread = 0
        cell.unreadWidth.constant = 0
        cell.unread.isHidden = true
        cell.accessibilityValue = article.title
    }

    private func configureCellToShowUnread(_ cell: ArticleCell, article: Article) -> String {
        cell.unread.unread = article.read ? 0 : 1
        cell.unreadWidth.constant = article.read ? 0 : 30
        cell.unread.isHidden = article.read
        if article.read {
            return NSLocalizedString("ArticleCell_Accessibility_Value_Read", comment: "")
        } else {
            return NSLocalizedString("ArticleCell_Accessibility_Value_Unread", comment: "")
        }
    }

    func configureCellToShowReadingTime(_ cell: ArticleCell, article: Article) -> String {
        cell.readingTime.isHidden = false
        let readingSeconds = self.articleCoordinator.estimatedReadingTime(of: article)
        let readingTimeText = String.localizedStringWithFormat(
            NSLocalizedString("ArticleCell_EstimatedReadingTime", comment: ""),
            readingSeconds.minutes
        )
        cell.readingTime.text = readingTimeText
        return readingTimeText
    }

    func configureCellToHideReadingTime(_ cell: ArticleCell) {
        cell.readingTime.isHidden = true
        cell.readingTime.text = nil
    }
}

private extension TimeInterval {
    var minutes: Int {
        let timeInMinutes: Double = self / 60
        let roundedTimeInMinutes: Double = timeInMinutes.rounded()
        return Int(roundedTimeInMinutes)
    }
}
