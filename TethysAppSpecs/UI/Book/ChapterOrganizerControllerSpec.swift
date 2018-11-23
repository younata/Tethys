import Quick
import Nimble
import Tethys
import TethysKit

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
        var themeRepository: ThemeRepository!
        var delegate: FakeChapterOrganizerControllerDelegate!
        var settingsRepository: SettingsRepository!
        var articleCellController: FakeArticleCellController!
        var navController: UINavigationController!
        var tableView: UITableView!

        let allArticles: [Article] = [
            Article(title: "Article 1", link: URL(string: "https://example.com/1")!, summary: "", authors: [],
                    published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                    synced: false, feed: nil, flags: []),
            Article(title: "Article 2", link: URL(string: "https://example.com/2")!, summary: "", authors: [],
                    published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                    synced: false, feed: nil, flags: []),
            Article(title: "Article 3", link: URL(string: "https://example.com/3")!, summary: "", authors: [],
                    published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                    synced: false, feed: nil, flags: []),
            Article(title: "Article 4", link: URL(string: "https://example.com/4")!, summary: "", authors: [],
                    published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                    synced: false, feed: nil, flags: []),
            Article(title: "Article 5", link: URL(string: "https://example.com/5")!, summary: "", authors: [],
                    published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                    synced: false, feed: nil, flags: []),
            Article(title: "Article 6", link: URL(string: "https://example.com/6")!, summary: "", authors: [],
                    published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                    synced: false, feed: nil, flags: []),
        ]

        let articlesCollection = AnyCollection(allArticles)

        beforeEach {
            themeRepository = ThemeRepository(userDefaults: nil)
            settingsRepository = SettingsRepository(userDefaults: nil)
            articleCellController = FakeArticleCellController()
            delegate = FakeChapterOrganizerControllerDelegate()

            subject = ChapterOrganizerController(
                themeRepository: themeRepository,
                settingsRepository: settingsRepository,
                articleCellController: articleCellController,
                articleListController: {
                    ArticleListController(
                        mainQueue: FakeOperationQueue(),
                        feedRepository: FakeDatabaseUseCase(),
                        themeRepository: themeRepository,
                        settingsRepository: settingsRepository,
                        articleCellController: articleCellController,
                        articleViewController: { fatalError() },
                        generateBookViewController: { fatalError() }
                    )
                }
            )

            navController = UINavigationController(rootViewController: subject)

            subject.view.layoutIfNeeded()
            subject.articles = articlesCollection

            subject.delegate = delegate

            tableView = subject.actionableTableView.tableView
        }

        describe("listening to theme repository updates") {
            beforeEach {
                subject.viewWillAppear(false)
                themeRepository.theme = .dark
            }

            it("should update the tableView") {
                expect(tableView.backgroundColor) == themeRepository.backgroundColor
                expect(tableView.separatorColor) == themeRepository.textColor
            }

            it("should update the tableView scroll indicator style") {
                expect(tableView.indicatorStyle) == themeRepository.scrollIndicatorStyle
            }
        }

        it("sets the actionableTableView's themeRepository") {
            expect(subject.actionableTableView.themeRepository) === themeRepository
        }

        it("sets the addChapterButton title") {
            expect(subject.addChapterButton.title(for: .normal)) == "Add Chapter"
        }

        describe("the reorder button") {
            it("is initially disabled") {
                expect(subject.reorderButton.isEnabled) == false
            }

            it("is titled 'Reorder'") {
                expect(subject.reorderButton.title(for: .normal)) == "Reorder"
            }
        }

        describe("tapping the add chapter button") {
            beforeEach {
                subject.delegate = nil
                subject.chapters = [allArticles.first!, allArticles.last!]
                subject.delegate = delegate

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
                    allArticles[0],
                    allArticles[1],
                    allArticles[2],
                ]

                beforeEach {
                    guard let articleList = navController.visibleViewController as? ArticleListController else { return }
                    articleList.delegate?.articleListController(articleList, didSelectArticles: articles)
                }

                it("dismisses the article list") {
                    expect(navController.visibleViewController) == subject
                }

                it("sets the chapters") {
                    expect(subject.chapters) == [allArticles[0], allArticles[5], allArticles[1], allArticles[2]]
                }

                it("updates the tableView") {
                    expect(tableView.numberOfRows(inSection: 0)) == articles.count + 1
                }

                it("enables the reorder button") {
                    expect(subject.reorderButton.isEnabled) == true
                }

                describe("the chapter cells") {
                    var cell: ArticleCell?

                    beforeEach {
                        cell = tableView.dataSource?.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0)) as? ArticleCell
                        expect(cell).toNot(beNil())
                    }

                    it("is configured with the themeRepository") {
                        expect(cell?.themeRepository) == themeRepository
                    }

                    it("shows the associated article, using the article cell controller") {
                        expect(articleCellController.configureCalls).to(haveCount(1))
                        guard let call = articleCellController.configureCalls.last else { return }

                        expect(call.cell).to(equal(cell))
                        expect(call.article).to(equal(articles[0]))
                    }
                }

                it("informs the delegate that chapters has changed") {
                    expect(delegate.didChangeChaptersCallCount) == 1
                }

                describe("tapping the reorder button") {
                    beforeEach {
                        subject.reorderButton.sendActions(for: .touchUpInside)
                    }

                    it("changes the text to 'Done'") {
                        expect(subject.reorderButton.title(for: .normal)) == "Done"
                    }

                    it("enables edit mode on the tableView") {
                        expect(tableView.isEditing) == true
                    }

                    it("doesn't show the delete icon on the cell") {
                        expect(tableView.delegate?.tableView?(tableView, editingStyleForRowAt: IndexPath(row: 0, section: 0))) == UITableViewCellEditingStyle.none
                    }

                    describe("tapping the reorder button again") {
                        beforeEach {
                            subject.reorderButton.sendActions(for: .touchUpInside)
                        }

                        it("resets the text") {
                            expect(subject.reorderButton.title(for: .normal)) == "Reorder"
                        }

                        it("disables edit mode on the tableView") {
                            expect(tableView.isEditing) == false
                        }

                        it("shows the delete message on the cell") {
                            expect(tableView.delegate?.tableView?(tableView, editingStyleForRowAt: IndexPath(row: 0, section: 0))) == UITableViewCellEditingStyle.delete
                        }
                    }
                }

                describe("moving a chapter") {
                    it("can move chapters") {
                        for i in 0..<articles.count {
                            expect(tableView.dataSource?.tableView?(tableView, canMoveRowAt: IndexPath(row: i, section: 0))) == true
                        }
                    }

                    it("rearranges the internal chapter order when the user moves the cells") {
                        tableView.dataSource?.tableView?(tableView, moveRowAt: IndexPath(row: 0, section: 0), to: IndexPath(row: 2, section: 0))

                        expect(subject.chapters) == [
                            allArticles.last!,
                            articles[1],
                            articles[0],
                            articles[2],
                        ]
                    }

                    it("informs the delegate that chapters change when moving") {
                        tableView.dataSource?.tableView?(tableView, moveRowAt: IndexPath(row: 0, section: 0), to: IndexPath(row: 2, section: 0))

                        expect(delegate.didChangeChaptersCallCount) == 2
                    }
                }

                describe("edit actions of the tableView") {
                    it("each cell has one edit action") {
                        for i in 0..<articles.count {
                            let editActions = tableView.delegate?.tableView?(tableView, editActionsForRowAt: IndexPath(row: i, section: 0))
                            expect(editActions?.count) == 1
                            expect(editActions?.first?.title) == "Delete"
                        }
                    }

                    describe("tapping the edit action") {
                        beforeEach {
                            let editAction = tableView.delegate?.tableView?(tableView, editActionsForRowAt: IndexPath(row: 0, section: 0))?.first
                            editAction?.handler?(editAction!, IndexPath(row: 0, section: 0))
                        }

                        it("deletes the chapter from the list") {
                            expect(subject.chapters) == [
                                allArticles[5],
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
