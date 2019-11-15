import Quick
import Nimble

@testable import Tethys
import TethysKit

final class ArticleCellControllerSpec: QuickSpec {
    override func spec() {
        var subject: ArticleCellController!

        var settingsRepository: SettingsRepository!
        var articleCoordinator: FakeArticleCoordinator!

        var cell: ArticleCell!

        beforeEach {
            settingsRepository = SettingsRepository(userDefaults: nil)
            articleCoordinator = FakeArticleCoordinator()

            cell = ArticleCell(frame: .zero)
        }

        func itShowsAnArticle(title: String, date: String, author: String) {
            describe("Showing an Article") {
                it("sets the title label") {
                    expect(cell.title.text).to(equal(title))
                }

                it("sets the published label") {
                    expect(cell.published.text).to(equal(date))
                }

                it("sets the author label") {
                    expect(cell.author.text).to(equal(author))
                }
            }
        }

        func itShowsAnUnreadArticle() {
            describe("Display an unread article") {
                it("shows the unread counter") {
                    expect(cell.unread.isHidden).to(beFalse())
                }

                it("sets the unread value to non-zero") {
                    expect(cell.unread.unread).to(beGreaterThan(0))
                }

                it("makes sure there's room to view it") {
                    expect(cell.unreadWidth.constant).to(beCloseTo(30))
                }
            }
        }

        func itShowsAReadArticle() {
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

        func itDisplaysReadingTime(expectedReadingTime: String, line: UInt = #line) {
            it("displays estimated reading time") {
                expect(cell.readingTime.isHidden, line: line).to(beFalse())
                expect(cell.readingTime.text, line: line).to(equal(expectedReadingTime))
            }

            it("asks the article service for the estimated reading time") {
                expect(articleCoordinator.estimatedReadingTimeCalls, line: line).to(haveCount(1))
            }
        }

        func itHidesReadingTime() {
            it("does not display estimated reading time") {
                expect(cell.readingTime.isHidden).to(beTrue())
                expect(cell.readingTime.text ?? "").to(beEmpty())
            }

            it("doesn't even ask for estimated reading time") {
                expect(articleCoordinator.estimatedReadingTimeCalls).to(beEmpty())
            }
        }

        context("When estimated reading time is disabled") {
            beforeEach {
                settingsRepository.showEstimatedReadingLabel = false
            }

            context("when configured to not hide unread status") {
                beforeEach {
                    subject = DefaultArticleCellController(
                        hideUnread: false,
                        articleCoordinator: articleCoordinator,
                        settingsRepository: settingsRepository
                    )
                }

                context("with an article that hasn't been read yet") {
                    beforeEach {
                        let article = articleFactory(
                            title: "my title",
                            read: false
                        )

                        articleCoordinator.dateForArticleStub[article] = Date(timeIntervalSinceReferenceDate: 0)
                        articleCoordinator.authorStub[article] = "A Few Authors"

                        subject.configure(cell: cell, with: article)
                    }

                    itShowsAnArticle(title: "my title", date: "12/31/00", author: "A Few Authors")

                    itShowsAnUnreadArticle()

                    itHidesReadingTime()

                    it("is configured for accessibility") {
                        expect(cell.isAccessibilityElement).to(beTrue())
                        expect(cell.accessibilityTraits).to(equal([.button]))
                        expect(cell.accessibilityLabel).to(equal("Article"))
                        expect(cell.accessibilityValue).to(equal("my title, unread"))
                    }
                }

                context("with an article that has been read") {
                    beforeEach {
                        let article = articleFactory(
                            title: "my title",
                            read: true
                        )

                        articleCoordinator.dateForArticleStub[article] = Date(timeIntervalSinceReferenceDate: 0)
                        articleCoordinator.authorStub[article] = "A Few Authors"

                        subject.configure(cell: cell, with: article)
                    }

                    itShowsAnArticle(title: "my title", date: "12/31/00", author: "A Few Authors")

                    itShowsAReadArticle()

                    itHidesReadingTime()

                    it("is configured for accessibility") {
                        expect(cell.isAccessibilityElement).to(beTrue())
                        expect(cell.accessibilityTraits).to(equal([.button]))
                        expect(cell.accessibilityLabel).to(equal("Article"))
                        expect(cell.accessibilityValue).to(equal("my title, read"))
                    }
                }
            }

            context("when configured to hide unread status") {
                beforeEach {
                    subject = DefaultArticleCellController(
                        hideUnread: true,
                        articleCoordinator: articleCoordinator,
                        settingsRepository: settingsRepository
                    )

                }

                context("with an article that hasn't been read yet") {
                    beforeEach {
                        let article = articleFactory(
                            title: "my title",
                            read: false
                        )

                        articleCoordinator.dateForArticleStub[article] = Date(timeIntervalSinceReferenceDate: 0)
                        articleCoordinator.authorStub[article] = "A Few Authors"

                        subject.configure(cell: cell, with: article)
                    }

                    itShowsAnArticle(title: "my title", date: "12/31/00", author: "A Few Authors")

                    itShowsAReadArticle()

                    itHidesReadingTime()

                    it("is configured for accessibility") {
                        expect(cell.isAccessibilityElement).to(beTrue())
                        expect(cell.accessibilityTraits).to(equal([.button]))
                        expect(cell.accessibilityLabel).to(equal("Article"))
                        expect(cell.accessibilityValue).to(equal("my title"))
                    }
                }

                context("with an article that has been read") {
                    beforeEach {
                        let article = articleFactory(
                            title: "my title",
                            read: true
                        )

                        articleCoordinator.dateForArticleStub[article] = Date(timeIntervalSinceReferenceDate: 0)
                        articleCoordinator.authorStub[article] = "A Few Authors"

                        subject.configure(cell: cell, with: article)
                    }

                    itShowsAnArticle(title: "my title", date: "12/31/00", author: "A Few Authors")

                    itShowsAReadArticle()

                    itHidesReadingTime()

                    it("is configured for accessibility") {
                        expect(cell.isAccessibilityElement).to(beTrue())
                        expect(cell.accessibilityTraits).to(equal([.button]))
                        expect(cell.accessibilityLabel).to(equal("Article"))
                        expect(cell.accessibilityValue).to(equal("my title"))
                    }
                }
            }
        }

        context("When estimated reading time is enabled") {
            beforeEach {
                settingsRepository.showEstimatedReadingLabel = true
            }

            context("when configured to not hide unread status") {
                beforeEach {
                    subject = DefaultArticleCellController(
                        hideUnread: false,
                        articleCoordinator: articleCoordinator,
                        settingsRepository: settingsRepository
                    )
                }

                context("with an article that hasn't been read yet") {
                    beforeEach {
                        let article = articleFactory(
                            title: "my title",
                            read: false
                        )

                        articleCoordinator.dateForArticleStub[article] = Date(timeIntervalSinceReferenceDate: 0)
                        articleCoordinator.authorStub[article] = "A Few Authors"
                        articleCoordinator.estimatedReadingTimeStub[article] = 29

                        subject.configure(cell: cell, with: article)
                    }

                    itShowsAnArticle(title: "my title", date: "12/31/00", author: "A Few Authors")

                    itShowsAnUnreadArticle()

                    itDisplaysReadingTime(expectedReadingTime: "Less than 1 minute to read")

                    it("is configured for accessibility") {
                        expect(cell.isAccessibilityElement).to(beTrue())
                        expect(cell.accessibilityTraits).to(equal([.button]))
                        expect(cell.accessibilityLabel).to(equal("Article"))
                        expect(cell.accessibilityValue).to(equal("my title, unread, Less than 1 minute to read"))
                    }
                }

                context("with an article that has been read") {
                    beforeEach {
                        let article = articleFactory(
                            title: "my title",
                            read: true
                        )

                        articleCoordinator.dateForArticleStub[article] = Date(timeIntervalSinceReferenceDate: 0)
                        articleCoordinator.authorStub[article] = "A Few Authors"
                        articleCoordinator.estimatedReadingTimeStub[article] = 60

                        subject.configure(cell: cell, with: article)
                    }

                    itShowsAnArticle(title: "my title", date: "12/31/00", author: "A Few Authors")

                    itShowsAReadArticle()

                    itDisplaysReadingTime(expectedReadingTime: "1 minute to read")

                    it("is configured for accessibility") {
                        expect(cell.isAccessibilityElement).to(beTrue())
                        expect(cell.accessibilityTraits).to(equal([.button]))
                        expect(cell.accessibilityLabel).to(equal("Article"))
                        expect(cell.accessibilityValue).to(equal("my title, read, 1 minute to read"))
                    }
                }
            }

            context("when configured to hide unread status") {
                beforeEach {
                    subject = DefaultArticleCellController(
                        hideUnread: true,
                        articleCoordinator: articleCoordinator,
                        settingsRepository: settingsRepository
                    )

                }

                context("with an article that hasn't been read yet") {
                    beforeEach {
                        let article = articleFactory(
                            title: "my title",
                            read: false
                        )

                        articleCoordinator.dateForArticleStub[article] = Date(timeIntervalSinceReferenceDate: 0)
                        articleCoordinator.authorStub[article] = "A Few Authors"
                        articleCoordinator.estimatedReadingTimeStub[article] = 120

                        subject.configure(cell: cell, with: article)
                    }

                    itShowsAnArticle(title: "my title", date: "12/31/00", author: "A Few Authors")

                    itShowsAReadArticle()

                    itDisplaysReadingTime(expectedReadingTime: "2 minutes to read")

                    it("is configured for accessibility") {
                        expect(cell.isAccessibilityElement).to(beTrue())
                        expect(cell.accessibilityTraits).to(equal([.button]))
                        expect(cell.accessibilityLabel).to(equal("Article"))
                        expect(cell.accessibilityValue).to(equal("my title, 2 minutes to read"))
                    }
                }

                context("with an article that has been read") {
                    beforeEach {
                        let article = articleFactory(
                            title: "my title",
                            read: true
                        )

                        articleCoordinator.dateForArticleStub[article] = Date(timeIntervalSinceReferenceDate: 0)
                        articleCoordinator.authorStub[article] = "A Few Authors"
                        articleCoordinator.estimatedReadingTimeStub[article] = 180

                        subject.configure(cell: cell, with: article)
                    }

                    itShowsAnArticle(title: "my title", date: "12/31/00", author: "A Few Authors")

                    itShowsAReadArticle()

                    itDisplaysReadingTime(expectedReadingTime: "3 minutes to read")

                    it("is configured for accessibility") {
                        expect(cell.isAccessibilityElement).to(beTrue())
                        expect(cell.accessibilityTraits).to(equal([.button]))
                        expect(cell.accessibilityLabel).to(equal("Article"))
                        expect(cell.accessibilityValue).to(equal("my title, 3 minutes to read"))
                    }
                }
            }
        }
    }
}
