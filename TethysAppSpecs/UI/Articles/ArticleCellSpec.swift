import Quick
import Nimble
import Tethys
import TethysKit

class ArticleCellSpec: QuickSpec {
    override func spec() {
        var subject: ArticleCell! = nil

        beforeEach {
            subject = ArticleCell(style: .default, reuseIdentifier: nil)
        }

        describe("theming") {

            it("updates each label") {
                expect(subject.title.textColor).to(equal(Theme.textColor))
                expect(subject.published.textColor).to(equal(Theme.textColor))
                expect(subject.author.textColor).to(equal(Theme.textColor))
                expect(subject.readingTime.textColor).to(equal(Theme.textColor))
            }

            it("changes the cell's background colors") {
                expect(subject.backgroundColor).to(equal(Theme.backgroundColor))
            }

            it("updates the unreadCounter's triangleColor") {
                expect(subject.unread.triangleColor).to(equal(Theme.highlightColor))
            }
        }
    }
}
