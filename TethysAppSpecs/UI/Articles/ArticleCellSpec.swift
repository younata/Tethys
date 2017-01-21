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
                expect(subject.title.textColor) == themeRepository.textColor
                expect(subject.published.textColor) == themeRepository.textColor
                expect(subject.author.textColor) == themeRepository.textColor
                expect(subject.readingTime.textColor) == themeRepository.textColor
            }

            it("changes the cell's background colors") {
                expect(subject.backgroundColor) == themeRepository.backgroundColor
            }
        }

        describe("configure(title:publishedDate:author:read:readingTime:)") {
            beforeEach {
                subject.configure(
                    title: "title",
                    publishedDate: Date(timeIntervalSinceReferenceDate: 0),
                    author: "Rachel",
                    read: false,
                    readingTime: nil
                )
            }

            it("sets the title label") {
                expect(subject.title.text) == "title"
            }

            it("sets the published label") {
                let dateFormatter = DateFormatter()

                dateFormatter.timeStyle = .none
                dateFormatter.dateStyle = .short
                dateFormatter.timeZone = NSCalendar.current.timeZone

                expect(subject.published.text) == dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: 0))
            }

            it("sets the author label") {
                expect(subject.author.text) == "Rachel"
            }

            it("indicates that it's unread") {
                expect(subject.unread.unread) == 1
            }

            it("doesn't show the unread indicator when 'hideUnread' is set") {
                subject.hideUnread = true
                expect(subject.unread.unread) == 0
            }

            it("still doesn't show the unread indicator when read is set to true") {
                subject.hideUnread = false
                subject.configure(
                    title: "title",
                    publishedDate: Date(timeIntervalSinceReferenceDate: 0),
                    author: "Rachel",
                    read: true,
                    readingTime: nil
                )
                expect(subject.unread.unread) == 0
            }

            it("doesn't show the reading time label when readingTime is nil") {
                expect(subject.readingTime.isHidden) == true
                expect(subject.readingTime.text).to(beNil())
            }

            it("doesn't show the reading time label when the readingTime is zero") {
                subject.configure(
                    title: "title",
                    publishedDate: Date(timeIntervalSinceReferenceDate: 0),
                    author: "Rachel",
                    read: true,
                    readingTime: 0
                )
                expect(subject.readingTime.isHidden) == true
                expect(subject.readingTime.text).to(beNil())
            }

            it("shows the reading time label when the readingTime is greater than 0") {
                subject.configure(
                    title: "title",
                    publishedDate: Date(timeIntervalSinceReferenceDate: 0),
                    author: "Rachel",
                    read: true,
                    readingTime: 15
                )
                expect(subject.readingTime.isHidden) == false
                expect(subject.readingTime.text) == "15 minutes to read"
            }
        }
    }
}
