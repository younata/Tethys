import Quick
import Nimble
import rNews
import rNewsKit

class ArticleCellSpec: QuickSpec {
    override func spec() {
        var subject: ArticleCell! = nil
        var themeRepository: ThemeRepository! = nil
        var settingsRepository: SettingsRepository! = nil

        let unupdatedArticle = Article(title: "title", link: URL(string: "https://exapmle.com/1")!, summary: "summary", authors: [Author(name: "Rachel", email: nil)], published: Date(timeIntervalSinceReferenceDate: 0), updatedAt: nil, identifier: "", content: "content", read: false, estimatedReadingTime: 10, feed: nil, flags: [])
        let readArticle = Article(title: "title", link: URL(string: "https://exapmle.com/1")!, summary: "summary", authors: [], published: Date(timeIntervalSinceReferenceDate: 0), updatedAt: Date(timeIntervalSinceReferenceDate: 100000), identifier: "", content: "content", read: true, estimatedReadingTime: 0, feed: nil, flags: [])

        beforeEach {
            subject = ArticleCell(style: .default, reuseIdentifier: nil)
            themeRepository = ThemeRepository(userDefaults: nil)
            settingsRepository = SettingsRepository(userDefaults: nil)
            subject.article = unupdatedArticle
            subject.themeRepository = themeRepository
            subject.settingsRepository = settingsRepository
        }

       describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("updates each label") {
                expect(subject.title.textColor) == themeRepository.textColor
                expect(subject.published.textColor) == themeRepository.textColor
                expect(subject.author.textColor) == themeRepository.textColor
                expect(subject.readingTime.textColor) == themeRepository.textColor
            }

            it("changes the cell's background colors") {
                expect(subject.backgroundColor) == themeRepository.backgroundColor
            }
        }

        describe("turning off SettingsRepository.showEstimatedReadingLabel") {
            beforeEach {
                settingsRepository.showEstimatedReadingLabel = false
            }

            it("removes the readingTime label from the view hierarchy") {
                expect(subject.readingTime.isHidden) == true

            }

            it("re-adds the readingTime label to the view hierarchy when the user turns back on reading label") {
                settingsRepository.showEstimatedReadingLabel = true
                expect(subject.readingTime.isHidden) == false
            }
        }

        it("should set the title label") {
            expect(subject.title.text) == "title"
        }

        it("should set the published/updated label") {
            let dateFormatter = DateFormatter()

            dateFormatter.timeStyle = .none
            dateFormatter.dateStyle = .short
            dateFormatter.timeZone = NSCalendar.current.timeZone

            expect(subject.published.text) == dateFormatter.string(from: unupdatedArticle.published)
        }

        it("should show the author") {
            expect(subject.author.text) == "Rachel"
        }

        it("should indicate that it's unread") {
            expect(subject.unread.unread) != 0
        }

        context("setting an read article") {
            beforeEach {
                subject.article = readArticle
            }

            it("should indicate that it's read") {
                expect(subject.unread.unread) == 0
            }
        }

        context("setting a decently long article") {
            beforeEach {
                subject.article = Article(title: "title", link: URL(string: "https://exapmle.com/1")!, summary: "summary", authors: [], published: Date(timeIntervalSinceReferenceDate: 0), updatedAt: nil, identifier: "", content: "content", read: false, estimatedReadingTime: 15, feed: nil, flags: [])
            }

            it("should show the estimated reading time") {
                expect(subject.readingTime.isHidden) == false
                expect(subject.readingTime.text) == "15 minutes to read"
            }
        }

        context("setting an updated article") {
            beforeEach {
                subject.article = readArticle
            }

            it("should set the published/updated label") {
                let dateFormatter = DateFormatter()

                dateFormatter.timeStyle = .none
                dateFormatter.dateStyle = .short
                dateFormatter.timeZone = NSCalendar.current.timeZone

                expect(subject.published.text) == dateFormatter.string(from: readArticle.updatedAt!)
            }
        }
    }
}
