import Quick
import Nimble
import rNews
import rNewsKit

class ArticleCellSpec: QuickSpec {
    override func spec() {
        var subject: ArticleCell! = nil
        var themeRepository: FakeThemeRepository! = nil

        let unupdatedArticle = Article(title: "title", link: nil, summary: "summary", author: "Rachel", published: NSDate(timeIntervalSinceReferenceDate: 0), updatedAt: nil, identifier: "", content: "content", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
        let readArticle = Article(title: "title", link: nil, summary: "summary", author: "Rachel", published: NSDate(timeIntervalSinceReferenceDate: 0), updatedAt: NSDate(timeIntervalSinceReferenceDate: 100000), identifier: "", content: "content", read: true, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])

        beforeEach {
            subject = ArticleCell(style: .Default, reuseIdentifier: nil)
            themeRepository = FakeThemeRepository()
            subject.article = unupdatedArticle
            subject.themeRepository = themeRepository
        }

       describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("updates each label") {
                expect(subject.title.textColor).to(equal(themeRepository.textColor))
                expect(subject.published.textColor).to(equal(themeRepository.textColor))
                expect(subject.author.textColor).to(equal(themeRepository.textColor))
            }

            it("changes the cell's background colors") {
                expect(subject.backgroundColor).to(equal(themeRepository.backgroundColor))
            }
        }

        it("should set the title label") {
            expect(subject.title.text).to(equal("title"))
        }

        it("should set the published/updated label") {
            let dateFormatter = NSDateFormatter()

            dateFormatter.timeStyle = .NoStyle
            dateFormatter.dateStyle = .ShortStyle
            dateFormatter.timeZone = NSCalendar.currentCalendar().timeZone

            expect(subject.published.text).to(equal(dateFormatter.stringFromDate(unupdatedArticle.published)))
        }

        it("should show the author") {
            expect(subject.author.text).to(equal("Rachel"))
        }

        it("should indicate that it's unread") {
            expect(subject.unread.unread).toNot(equal(0))
        }

        context("setting an read article") {
            beforeEach {
                subject.article = readArticle
            }

            it("should indicate that it's read") {
                expect(subject.unread.unread).to(equal(0))
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

                expect(subject.published.text).to(equal(dateFormatter.stringFromDate(readArticle.updatedAt!)))
            }
        }
    }
}
