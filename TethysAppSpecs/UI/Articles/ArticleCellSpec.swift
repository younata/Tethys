import Quick
import Nimble
import Tethys
import TethysKit

class ArticleCellSpec: QuickSpec {
    override func spec() {
        var subject: ArticleCell! = nil
        var themeRepository: ThemeRepository! = nil

        beforeEach {
            subject = ArticleCell(style: .default, reuseIdentifier: nil)
            themeRepository = ThemeRepository(userDefaults: nil)
            subject.themeRepository = themeRepository
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("updates each label") {
                expect(subject.title.textColor).to(equal(themeRepository.textColor))
                expect(subject.published.textColor).to(equal(themeRepository.textColor))
                expect(subject.author.textColor).to(equal(themeRepository.textColor))
                expect(subject.readingTime.textColor).to(equal(themeRepository.textColor))
            }

            it("changes the cell's background colors") {
                expect(subject.backgroundColor).to(equal(themeRepository.backgroundColor))
            }

            it("updates the unreadCounter's triangleColor") {
                expect(subject.unread.triangleColor).to(equal(themeRepository.highlightColor))
            }
        }
    }
}
