import Quick
import Nimble

import Tethys
import TethysKit

final class ArticleCellControllerSpec: QuickSpec {
    override func spec() {
        var subject: ArticleCellController!

        var settingsRepository: SettingsRepository!
        var articleService: FakeArticleService!

        var cell: ArticleCell!

        beforeEach {
            settingsRepository = SettingsRepository(userDefaults: nil)
            articleService = FakeArticleService()

            cell = ArticleCell(frame: .zero)
        }

        func itBehavesLikeShowing(title: String, date: String, author: String) {
            describe("Showing an Article") {
                it("sets the title label") {
                    expect(cell.title.text) == title
                }

                it("sets the published label") {
                    expect(cell.published.text) == date
                }

                it("sets the author label") {
                    expect(cell.author.text) == author
                }
            }
        }

        context("when configured to not hide unread status") {
            beforeEach {
                subject = DefaultArticleCellController(
                    hideUnread: false,
                    articleService: articleService,
                    settingsRepository: settingsRepository
                )
            }

            xdescribe("configure(title:publishedDate:author:read:readingTime:)") {
                beforeEach {
//                    subject.configure(
//                        title: "title",
//                        publishedDate: Date(timeIntervalSinceReferenceDate: 0),
//                        author: "Rachel",
//                        read: false,
//                        readingTime: nil
//                    )
                }
//                it("indicates that it's unread") {
//                    expect(subject.unread.unread) == 1
//                }
//
//                it("doesn't show the unread indicator when 'hideUnread' is set") {
//                    subject.hideUnread = true
//                    expect(subject.unread.unread) == 0
//                }
//
//                it("still doesn't show the unread indicator when read is set to true") {
//                    subject.hideUnread = false
//                    subject.configure(
//                        title: "title",
//                        publishedDate: Date(timeIntervalSinceReferenceDate: 0),
//                        author: "Rachel",
//                        read: true,
//                        readingTime: nil
//                    )
//                    expect(subject.unread.unread) == 0
//                }
//
//                it("doesn't show the reading time label when readingTime is nil") {
//                    expect(subject.readingTime.isHidden) == true
//                    expect(subject.readingTime.text).to(beNil())
//                }
//
//                it("doesn't show the reading time label when the readingTime is zero") {
//                    subject.configure(
//                        title: "title",
//                        publishedDate: Date(timeIntervalSinceReferenceDate: 0),
//                        author: "Rachel",
//                        read: true,
//                        readingTime: 0
//                    )
//                    expect(subject.readingTime.isHidden) == true
//                    expect(subject.readingTime.text).to(beNil())
//                }
//
//                it("shows the reading time label when the readingTime is greater than 0") {
//                    subject.configure(
//                        title: "title",
//                        publishedDate: Date(timeIntervalSinceReferenceDate: 0),
//                        author: "Rachel",
//                        read: true,
//                        readingTime: 15
//                    )
//                    expect(subject.readingTime.isHidden) == false
//                    expect(subject.readingTime.text) == "15 minutes to read"
//                }
            }
        }

        context("when configured to hide unread status") {

        }
    }
}
