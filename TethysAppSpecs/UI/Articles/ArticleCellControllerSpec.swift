import Quick
import Nimble

@testable import Tethys
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

        func itBehavesLikeDisplaysUnreadStatus() {
            describe("Display an unread article") {
                it("shows the unread counter") {
                    expect(cell.unread.isHidden) == false
                }

                it("sets the unread value to non-zero") {
                    expect(cell.unread.unread) > 0
                }

                it("makes sure there's room to view it") {
                    expect(cell.unreadWidth.constant).to(beCloseTo(30))
                }
            }
        }

        func itBehavesLikeDisplaysReadStatus() {
            describe("Display an unread article") {
                it("hides the unread counter") {
                    expect(cell.unread.isHidden) == true
                }

                it("sets the unread value to zero") {
                    expect(cell.unread.unread) == 0
                }

                it("doesn't allow room to view it anyway") {
                    expect(cell.unreadWidth.constant).to(beCloseTo(0))
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

            context("with an article that hasn't been read yet") {
                beforeEach {
                    let article = articleFactory(
                        title: "my title",
                        read: false
                    )

                    articleService.dateForArticleStub[article] = Date(timeIntervalSinceReferenceDate: 0)
                    articleService.authorStub[article] = "A Few Authors"

                    subject.configure(cell: cell, with: article)
                }

                itBehavesLikeShowing(title: "my title", date: "12/31/00", author: "A Few Authors")

                itBehavesLikeDisplaysUnreadStatus()
            }

            context("with an article that has been read") {
                beforeEach {
                    let article = articleFactory(
                        title: "my title",
                        read: true
                    )

                    articleService.dateForArticleStub[article] = Date(timeIntervalSinceReferenceDate: 0)
                    articleService.authorStub[article] = "A Few Authors"

                    subject.configure(cell: cell, with: article)
                }

                itBehavesLikeShowing(title: "my title", date: "12/31/00", author: "A Few Authors")

                itBehavesLikeDisplaysReadStatus()
            }
        }

        context("when configured to hide unread status") {
            beforeEach {
                subject = DefaultArticleCellController(
                    hideUnread: true,
                    articleService: articleService,
                    settingsRepository: settingsRepository
                )

            }

            context("with an article that hasn't been read yet") {
                beforeEach {
                    let article = articleFactory(
                        title: "my title",
                        read: false
                    )

                    articleService.dateForArticleStub[article] = Date(timeIntervalSinceReferenceDate: 0)
                    articleService.authorStub[article] = "A Few Authors"

                    subject.configure(cell: cell, with: article)
                }

                itBehavesLikeShowing(title: "my title", date: "12/31/00", author: "A Few Authors")

                itBehavesLikeDisplaysReadStatus()
            }

            context("with an article that has been read") {
                beforeEach {
                    let article = articleFactory(
                        title: "my title",
                        read: true
                    )

                    articleService.dateForArticleStub[article] = Date(timeIntervalSinceReferenceDate: 0)
                    articleService.authorStub[article] = "A Few Authors"

                    subject.configure(cell: cell, with: article)
                }

                itBehavesLikeShowing(title: "my title", date: "12/31/00", author: "A Few Authors")

                itBehavesLikeDisplaysReadStatus()
            }
        }
    }
}
