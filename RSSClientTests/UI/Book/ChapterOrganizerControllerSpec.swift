import Quick
import Nimble
import rNews
import rNewsKit
import Ra

class FakeChapterOrganizerControllerDelegate: ChapterOrganizerControllerDelegate {
    var didChangeChaptersCallCount: Int = 0
    private(set) var didChangeChaptersArgs: [ChapterOrganizerController] = []
    func didChangeChaptersArgsForCall(_ callIndex: Int) -> ChapterOrganizerController {
        return didChangeChaptersArgs[callIndex]
    }
    func chapterOrganizerControllerDidChangeChapters(_ chapterOrganizerController: ChapterOrganizerController) {
        didChangeChaptersCallCount += 1
        didChangeChaptersArgs.append(chapterOrganizerController)
    }
}

class ChapterOrganizerControllerSpec: QuickSpec {
    override func spec() {
        var subject: ChapterOrganizerController!
        var injector: Injector!
        var themeRepository: ThemeRepository!
        var delegate: FakeChapterOrganizerControllerDelegate!
        var settingsRepository: SettingsRepository!
        var navController: UINavigationController!

        let allArticles: [Article] = [
            Article(title: "Article 1", link: URL(string: "https://example.com/1")!, summary: "", authors: [],
                    published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                    estimatedReadingTime: 0, feed: nil, flags: []),
            Article(title: "Article 2", link: URL(string: "https://example.com/2")!, summary: "", authors: [],
                    published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                    estimatedReadingTime: 0, feed: nil, flags: []),
            Article(title: "Article 3", link: URL(string: "https://example.com/3")!, summary: "", authors: [],
                    published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                    estimatedReadingTime: 0, feed: nil, flags: []),
            Article(title: "Article 4", link: URL(string: "https://example.com/4")!, summary: "", authors: [],
                    published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                    estimatedReadingTime: 0, feed: nil, flags: []),
            Article(title: "Article 5", link: URL(string: "https://example.com/5")!, summary: "", authors: [],
                    published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                    estimatedReadingTime: 0, feed: nil, flags: []),
            Article(title: "Article 6", link: URL(string: "https://example.com/6")!, summary: "", authors: [],
                    published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                    estimatedReadingTime: 0, feed: nil, flags: []),
        ]

        let dataStoreArticles = DataStoreBackedArray(allArticles)

        beforeEach {
            injector = Injector()

            themeRepository = ThemeRepository(userDefaults: nil)

            injector.bind(kind: ThemeRepository.self, toInstance: themeRepository)
            injector.bind(kind: DatabaseUseCase.self, toInstance: FakeDatabaseUseCase())

            settingsRepository = SettingsRepository(userDefaults: nil)
            injector.bind(kind: SettingsRepository.self, toInstance: settingsRepository)

            delegate = FakeChapterOrganizerControllerDelegate()

            subject = injector.create(kind: ChapterOrganizerController.self)!

            navController = UINavigationController(rootViewController: subject)

            subject.view.layoutIfNeeded()
            subject.delegate = delegate
            subject.articles = dataStoreArticles
        }

        describe("listening to theme repository updates") {
            beforeEach {
                subject.viewWillAppear(false)
                themeRepository.theme = .dark
            }

            it("should update the tableView") {
                expect(subject.tableView.backgroundColor) == themeRepository.backgroundColor
                expect(subject.tableView.separatorColor) == themeRepository.textColor
            }

            it("should update the tableView scroll indicator style") {
                expect(subject.tableView.indicatorStyle) == themeRepository.scrollIndicatorStyle
            }
        }

        it("sets the addChapterButton title") {
            expect(subject.addChapterButton.title(for: .normal)) == "Add Chapter"
        }

        describe("tapping the add chapter button") {
            beforeEach {
                subject.addChapterButton.sendActions(for: .touchUpInside)
            }

            it("presents an article list controller") {
                expect(navController.visibleViewController).to(beAKindOf(ArticleListController.self))
            }

            it("configures the article list controller") {
                expect(navController.visibleViewController).to(beAKindOf(ArticleListController.self))
                guard let articleList = navController.visibleViewController as? ArticleListController else { return }

                expect(articleList.delegate).toNot(beNil())
                expect(articleList.delegate?.articleListControllerCanSelectMultipleArticles(articleList)) == true
                expect(Array(articleList.articles)) == allArticles

                let barItems = articleList.delegate?.articleListControllerRightBarButtonItems(articleList)
                expect(barItems?.count) == 1
                expect(barItems?.first?.title) == "Add"
                expect(barItems?.first?.target) === articleList
                expect(barItems?.first?.action) == #selector(ArticleListController.selectArticles)
            }

            describe("when the user is finished selecting articles") {
                let articles: [Article] = [
                    Article(title: "Article 1", link: URL(string: "https://example.com/1")!, summary: "", authors: [],
                            published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                            estimatedReadingTime: 0, feed: nil, flags: []),
                    Article(title: "Article 2", link: URL(string: "https://example.com/2")!, summary: "", authors: [],
                            published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                            estimatedReadingTime: 0, feed: nil, flags: []),
                    Article(title: "Article 3", link: URL(string: "https://example.com/3")!, summary: "", authors: [],
                            published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                            estimatedReadingTime: 0, feed: nil, flags: []),
                ]

                beforeEach {
                    guard let articleList = navController.visibleViewController as? ArticleListController else { return }
                    articleList.delegate?.articleListController(articleList, didSelectArticles: articles)
                }

                it("dismisses the article list") {
                    expect(navController.visibleViewController) == subject
                }

                it("sets the chapters") {
                    expect(subject.chapters) == articles
                }

                it("updates the tableView") {
                    expect(subject.tableView.numberOfRows(inSection: 0)) == articles.count
                }

                describe("the chapter cells") {
                    var cell: ArticleCell?

                    beforeEach {
                        cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: IndexPath(row: 0, section: 0)) as? ArticleCell
                        expect(cell).toNot(beNil())
                    }

                    it("is configured with the themeRepository") {
                        expect(cell?.themeRepository) == themeRepository
                    }

                    it("is configured with the settings repository") {
                        expect(cell?.settingsRepository) === settingsRepository
                    }

                    it("hides the unread indicator") {
                        expect(cell?.hideUnread) == true
                    }

                    it("shows the associated article") {
                        expect(cell?.article) == articles[0]
                    }
                }

                it("informs the delegate that chapters has changed") {
                    expect(delegate.didChangeChaptersCallCount) == 1
                }

                describe("moving a chapter") {
                    it("can move chapters") {
                        for i in 0..<articles.count {
                            expect(subject.tableView.dataSource?.tableView?(subject.tableView, canMoveRowAt: IndexPath(row: i, section: 0))) == true
                        }
                    }

                    it("rearranges the internal chapter order when the user moves the cells") {
                        subject.tableView.dataSource?.tableView?(subject.tableView, moveRowAt: IndexPath(row: 0, section: 0), to: IndexPath(row: 2, section: 0))

                        expect(subject.chapters) == [
                            articles[1],
                            articles[2],
                            articles[0]
                        ]
                    }

                    it("informs the delegate that chapters change when moving") {
                        subject.tableView.dataSource?.tableView?(subject.tableView, moveRowAt: IndexPath(row: 0, section: 0), to: IndexPath(row: 2, section: 0))

                        expect(delegate.didChangeChaptersCallCount) == 2
                    }
                }

                describe("edit actions of the tableView") {
                    it("each cell has one edit action") {
                        for i in 0..<articles.count {
                            let editActions = subject.tableView.delegate?.tableView?(subject.tableView, editActionsForRowAt: IndexPath(row: i, section: 0))
                            expect(editActions?.count) == 1
                            expect(editActions?.first?.title) == "Delete"
                        }
                    }

                    describe("tapping the edit action") {
                        beforeEach {
                            let editAction = subject.tableView.delegate?.tableView?(subject.tableView, editActionsForRowAt: IndexPath(row: 0, section: 0))?.first
                            editAction?.handler(editAction!, IndexPath(row: 0, section: 0))
                        }

                        it("deletes the chapter from the list") {
                            expect(subject.chapters) == [
                                articles[1],
                                articles[2]
                            ]
                        }

                        it("informs the delegate that chapters has changed") {
                            expect(delegate.didChangeChaptersCallCount) == 2
                        }
                    }
                }
            }
        }
    }
}
