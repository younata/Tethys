import Quick
import Nimble
import rNews
import rNewsKit

class ArticleCellSpec: QuickSpec {
    override func spec() {
        var subject: ArticleCell! = nil
        var themeRepository: FakeThemeRepository! = nil
        var settingsRepository: SettingsRepository! = nil

        let unupdatedArticle = Article(title: "title", link: nil, summary: "summary", authors: [Author(name: "Rachel", email: nil)], published: NSDate(timeIntervalSinceReferenceDate: 0), updatedAt: nil, identifier: "", content: "content", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
        let readArticle = Article(title: "title", link: nil, summary: "summary", authors: [], published: NSDate(timeIntervalSinceReferenceDate: 0), updatedAt: NSDate(timeIntervalSinceReferenceDate: 100000), identifier: "", content: "content", read: true, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])

        beforeEach {
            subject = ArticleCell(style: .Default, reuseIdentifier: nil)
            themeRepository = FakeThemeRepository()
            settingsRepository = SettingsRepository(userDefaults: nil)
            subject.article = unupdatedArticle
            subject.themeRepository = themeRepository
            subject.settingsRepository = settingsRepository
        }

       describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("updates each label") {
                expect(subject.title.textColor) == themeRepository.textColor
                expect(subject.published.textColor) == themeRepository.textColor
                expect(subject.author.textColor) == themeRepository.textColor
                expect(subject.readingTime.textColor) == themeRepository.textColor
                expect(subject.enclosures.textColor) == themeRepository.textColor
            }

            it("changes the cell's background colors") {
                expect(subject.backgroundColor) == themeRepository.backgroundColor
            }
        }

        describe("turning off SettingsRepository.showEstimatedReadingLabel") {
            beforeEach {
                settingsRepository.showEstimatedReadingLabel = false
            }

            it("hides the readingTime label") {
                expect(subject.readingTime.hidden) == true
            }
        }

        it("should set the title label") {
            expect(subject.title.text) == "title"
        }

        it("should set the published/updated label") {
            let dateFormatter = NSDateFormatter()

            dateFormatter.timeStyle = .NoStyle
            dateFormatter.dateStyle = .ShortStyle
            dateFormatter.timeZone = NSCalendar.currentCalendar().timeZone

            expect(subject.published.text) == dateFormatter.stringFromDate(unupdatedArticle.published)
        }

        it("should not show the estimated reading time") {
            expect(subject.readingTime.hidden) == true
        }

        it("should show the author") {
            expect(subject.author.text) == "Rachel"
        }

        it("should indicate that it's unread") {
            expect(subject.unread.unread) != 0
        }

        it("should not show the enclosures label") {
            expect(subject.enclosures.hidden) == true
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
                subject.article = Article(title: "title", link: nil, summary: "summary", authors: [], published: NSDate(timeIntervalSinceReferenceDate: 0), updatedAt: nil, identifier: "", content: "content", read: false, estimatedReadingTime: 15, feed: nil, flags: [], enclosures: [])
            }

            it("should show the estimated reading time") {
                expect(subject.readingTime.hidden) == false
                expect(subject.readingTime.text) == "15 minutes to read"
            }
        }

        context("setting an updated article") {
            beforeEach {
                subject.article = readArticle
            }

            it("should set the published/updated label") {
                let dateFormatter = NSDateFormatter()

                dateFormatter.timeStyle = .NoStyle
                dateFormatter.dateStyle = .ShortStyle
                dateFormatter.timeZone = NSCalendar.currentCalendar().timeZone

                expect(subject.published.text) == dateFormatter.stringFromDate(readArticle.updatedAt!)
            }
        }

        context("setting an article with a supported enclosure") {
            beforeEach {
                let enclosure = Enclosure(url: NSURL(string: "https://example.com/enclosure")!, kind: "video/mp4", article: nil)
                let article = Article(title: "title", link: nil, summary: "summary", authors: [], published: NSDate(timeIntervalSinceReferenceDate: 0), updatedAt: nil, identifier: "", content: "content", read: false, estimatedReadingTime: 15, feed: nil, flags: [], enclosures: [enclosure])
                enclosure.article = article
                subject.article = article
            }

            it("should show the enclosures label indicating 1 item") {
                expect(subject.enclosures.hidden) == false
                expect(subject.enclosures.text) == "1 item"
            }
        }

        context("setting an article with multiple supported enclosures") {
            beforeEach {
                let enclosure = Enclosure(url: NSURL(string: "https://example.com/enclosure")!, kind: "video/mp4", article: nil)
                let enclosure2 = Enclosure(url: NSURL(string: "https://example.com/enclosure2")!, kind: "video/mp4", article: nil)
                let article = Article(title: "title", link: nil, summary: "summary", authors: [], published: NSDate(timeIntervalSinceReferenceDate: 0), updatedAt: nil, identifier: "", content: "content", read: false, estimatedReadingTime: 15, feed: nil, flags: [], enclosures: [enclosure, enclosure2])
                enclosure.article = article
                enclosure2.article = article
                subject.article = article
            }

            it("should show the enclosures label indicating 2 items") {
                expect(subject.enclosures.hidden) == false
                expect(subject.enclosures.text) == "2 items"
            }
        }

        context("setting an article with no supported enclosures") {
            beforeEach {
                let enclosure = Enclosure(url: NSURL(string: "https://example.com/enclosure")!, kind: "application/json", article: nil)
                let article = Article(title: "title", link: nil, summary: "summary", authors: [], published: NSDate(timeIntervalSinceReferenceDate: 0), updatedAt: nil, identifier: "", content: "content", read: false, estimatedReadingTime: 15, feed: nil, flags: [], enclosures: [enclosure])
                enclosure.article = article
                subject.article = article
            }

            it("should not show the enclosures label") {
                expect(subject.enclosures.hidden) == true
            }
        }
    }
}
