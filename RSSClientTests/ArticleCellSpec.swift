import Quick
import Nimble
import rNews
import rNewsKit

class ArticleCellSpec: QuickSpec {
    override func spec() {
        var subject: ArticleCell! = nil
        let unupdatedArticle = Article(title: "title", link: nil, summary: "summary", author: "Rachel", published: NSDate(timeIntervalSinceReferenceDate: 0), updatedAt: nil, identifier: "", content: "content", read: false, feed: nil, flags: [], enclosures: [])
        let readArticle = Article(title: "title", link: nil, summary: "summary", author: "Rachel", published: NSDate(timeIntervalSinceReferenceDate: 0), updatedAt: NSDate(timeIntervalSinceReferenceDate: 100000), identifier: "", content: "content", read: true, feed: nil, flags: [], enclosures: [])

        beforeEach {
            subject = ArticleCell(style: .Default, reuseIdentifier: nil)
            subject.article = unupdatedArticle
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

            it("should indicate that it's unread") {
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
