import Quick
import Nimble
import rNews
import Ra
import rNewsKit

class QueryFeedViewControllerSpec: QuickSpec {
    override func spec() {
        var feed = Feed(title: "title", url: nil, summary: "summary", query: "function(article) {return !article.read;}",
            tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
        let otherFeed = Feed(title: "", url: nil, summary: "", query: "function(article) {return !article.read;}",
            tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

        var navigationController: UINavigationController!
        var subject: QueryFeedViewController! = nil
        var injector: Injector! = nil
        var feedRepository: FakeFeedRepository! = nil

        var backgroundQueue: FakeOperationQueue! = nil

        var themeRepository: FakeThemeRepository! = nil

        beforeEach {
            injector = Injector(module: SpecInjectorModule())

            backgroundQueue = FakeOperationQueue()
            backgroundQueue.runSynchronously = true
            injector.bind(kBackgroundQueue, toInstance: backgroundQueue)

            feedRepository = FakeFeedRepository()
            injector.bind(FeedRepository.self, toInstance: feedRepository)

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, toInstance: themeRepository)

            subject = injector.create(QueryFeedViewController)!

            navigationController = UINavigationController(rootViewController: subject)
        }

        describe("changing the theme") {
            beforeEach {
                subject.view.layoutIfNeeded()
                themeRepository.theme = .Dark
            }

            it("should update the tableView") {
                expect(subject.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                expect(subject.tableView.separatorColor).to(equal(themeRepository.textColor))
            }

            it("should update the tableView scroll indicator style") {
                expect(subject.tableView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
            }

            it("should update the navigation bar") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
            }
        }

        it("should have a save button") {
            expect(subject.view).toNot(beNil())
            expect(subject.navigationItem.rightBarButtonItem?.title).to(equal("Save"))
        }

        it("should have a dismiss button") {
            expect(subject.view).toNot(beNil())
            expect(subject.navigationItem.leftBarButtonItem?.title).to(equal("Dismiss"))
        }

        describe("tapping 'dismiss'") {
            var presentingController: UIViewController? = nil
            beforeEach {
                expect(subject.view).toNot(beNil())

                presentingController = UIViewController()
                presentingController?.presentViewController(navigationController, animated: false, completion: nil)

                let dismissButton = subject.navigationItem.leftBarButtonItem
                dismissButton?.tap()
            }

            it("should dismiss itself") {
                expect(presentingController?.presentedViewController).to(beNil())
            }
        }

        sharedExamples("saving data") {(sharedContext: SharedExampleContext) in
            var createFeed = false

            beforeEach {
                createFeed = sharedContext()["create"] as? Bool ?? false
            }

            it("should enable the save button") {
                expect(subject.navigationItem.rightBarButtonItem?.enabled) == true
            }

            describe("tapping 'save'") {
                var presentingController: UIViewController? = nil
                beforeEach {
                    presentingController = UIViewController()
                    presentingController?.presentViewController(navigationController, animated: false, completion: nil)

                    let saveButton = subject.navigationItem.rightBarButtonItem
                    saveButton?.tap()
                }

                it("should ask the data manager for a new feed if one didn't previously exist") {
                    expect(feedRepository.didCreateFeed).to(equal(createFeed))
                }

                describe("when the feed is created (or not)") {
                    beforeEach {
                        if createFeed {
                            feed = Feed(title: "", url: nil, summary: "", query: nil,
                                tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                            feedRepository.newFeedCallback(feed)
                        }
                    }

                    it("should modify the feed") {
                        let expectedFeedTitle = sharedContext()["title"] as? String
                        expect(expectedFeedTitle).toNot(beNil())

                        let expectedFeedSummary = sharedContext()["summary"] as? String ?? ""

                        let expectedFeedQuery = sharedContext()["query"] as? String
                        expect(expectedFeedQuery).toNot(beNil())

                        expect(feed.title).to(equal(expectedFeedTitle))
                        expect(feed.summary).to(equal(expectedFeedSummary))
                        expect(feed.query).to(equal(expectedFeedQuery))
                    }

                    it("should save the changes to the dataManager") {
                        expect(feedRepository.lastSavedFeed).to(equal(feed))
                    }

                    it("should dismiss itself") {
                        expect(presentingController?.presentedViewController).to(beNil())
                    }
                }
            }
        }

        context("when we're creating a new feed") {
            beforeEach {
                expect(subject.view).toNot(beNil())
                subject.tableView.reloadData()
            }

            it("should not enable the save button") {
                expect(subject.navigationItem.rightBarButtonItem?.enabled) == false
            }

            describe("the tableView") {
                it("should should have 3 sections") {
                    expect(subject.tableView.numberOfSections).to(equal(3))
                }

                describe("the first section") {
                    var cell: TextFieldCell? = nil
                    let indexPath = NSIndexPath(forRow: 0, inSection: 0)

                    it("should have 1 row") {
                        expect(subject.tableView.numberOfRowsInSection(0)).to(equal(1))
                    }

                    it("should be titled 'Title'") {
                        expect(subject.tableView(subject.tableView, titleForHeaderInSection: 0)).to(equal("Title"))
                    }

                    it("should not be editable") {
                        expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)) == false
                    }

                    describe("the cell") {
                        beforeEach {
                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath) as? TextFieldCell
                        }

                        it("should have a placeholder inviting the user to create a title") {
                            expect(cell?.textField.placeholder).to(equal("Enter a title"))
                        }

                        describe("on change") {
                            beforeEach {
                                cell?.textField.text = "a title"
                                cell?.onTextChange?("a title")
                            }

                            itBehavesLike("saving data") {
                                return [
                                    "title": "a title",
                                    "summary": "",
                                    "query": "function(article) {\n    return !article.read;\n}",
                                    "create": true,
                                ]
                            }
                        }

                        it("should have no edit actions") {
                            let editActions = subject.tableView(subject.tableView,
                                editActionsForRowAtIndexPath: indexPath)
                            expect(editActions).to(beNil())
                        }
                    }
                }

                describe("the second section") {
                    var cell: TextFieldCell? = nil
                    let indexPath = NSIndexPath(forRow: 0, inSection: 1)

                    it("should have 1 row") {
                        expect(subject.tableView.numberOfRowsInSection(1)).to(equal(1))
                    }

                    it("should be titled 'Summary'") {
                        expect(subject.tableView(subject.tableView, titleForHeaderInSection: 1)).to(equal("Summary"))
                    }

                    it("should not be editable") {
                        expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)) == false
                    }

                    describe("the cell") {
                        beforeEach {
                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath) as? TextFieldCell
                        }

                        it("should invite the user to set the summary") {
                            expect(cell?.textField.placeholder).to(equal("Enter a summary"))
                        }

                        describe("on change") {
                            beforeEach {
                                cell?.textField.text = "a summary"
                                cell?.onTextChange?("a summary")

                                let otherCell = subject.tableView(subject.tableView,
                                    cellForRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 0)) as? TextFieldCell
                                otherCell?.onTextChange?("a title")

                                let otherOtherCell = subject.tableView(subject.tableView,
                                    cellForRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 2)) as? TextViewCell
                                otherOtherCell?.textView.text = "a query"
                                if let textView = otherOtherCell?.textView {
                                    otherOtherCell?.textViewDidChange(textView)
                                }
                            }

                            itBehavesLike("saving data") {
                                return [
                                    "title": "a title",
                                    "summary": "a summary",
                                    "query": "a query",
                                    "create": true,
                                ]
                            }
                        }

                        it("should have no edit actions") {
                            let editActions = subject.tableView(subject.tableView,
                                editActionsForRowAtIndexPath: indexPath)
                            expect(editActions).to(beNil())
                        }
                    }
                }

                describe("the third section") {
                    var cell: TextViewCell? = nil
                    let indexPath = NSIndexPath(forRow: 0, inSection: 2)
                    it("should have 1 row") {
                        expect(subject.tableView.numberOfRowsInSection(2)).to(equal(1))
                    }

                    it("should be titled 'Query'") {
                        expect(subject.tableView(subject.tableView, titleForHeaderInSection: 2)).to(equal("Query"))
                    }

                    it("should be editable") {
                        expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)) == true
                    }

                    describe("the cell") {
                        beforeEach {
                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath) as? TextViewCell
                        }

                        it("should have a label title equal to the feed's") {
                            expect(cell?.textView.text).to(equal("function(article) {\n    return !article.read;\n}"))
                        }

                        describe("on change") {
                            beforeEach {
                                cell?.textView.text = "a query"
                                if let textView = cell?.textView {
                                    cell?.textViewDidChange(textView)
                                }
                                let otherCell = subject.tableView(subject.tableView,
                                    cellForRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 0)) as? TextFieldCell
                                otherCell?.onTextChange?("a title")
                            }

                            itBehavesLike("saving data") {
                                return [
                                    "title": "a title",
                                    "summary": "",
                                    "query": "a query",
                                    "create": true,
                                ]
                            }
                        }

                        describe("edit actions") {
                            var editActions: [UITableViewRowAction] = []
                            beforeEach {
                                editActions = subject.tableView(subject.tableView,
                                    editActionsForRowAtIndexPath: indexPath) ?? []
                            }

                            it("should have 1 edit action") {
                                expect(editActions.count).to(equal(1))
                            }

                            describe("the action") {
                                var action: UITableViewRowAction? = nil

                                beforeEach {
                                    action = editActions.first
                                }

                                it("should be titled 'Preview'") {
                                    expect(action?.title).to(equal("Preview"))
                                }

                                it("should show a preview of all articles it captures when tapped") {
                                    action?.handler()(action, indexPath)
                                    expect(navigationController.topViewController).to(beAnInstanceOf(ArticleListController.self))
                                    if let articleList = navigationController.topViewController as? ArticleListController {
                                        expect(articleList.previewMode) == true
                                        // TODO: fake articles
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        context("when we're modifying an existing feed") {
            beforeEach {
                feed = Feed(title: "title", url: nil, summary: "summary", query: "function(article) {return !article.read;}",
                    tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                subject.feed = feed

                expect(subject.view).toNot(beNil())
            }

            it("should enable the save button") {
                expect(subject.navigationItem.rightBarButtonItem?.enabled) == true
            }

            describe("the tableView") {
                it("should should have 4 sections") {
                    expect(subject.tableView.numberOfSections).to(equal(4))
                }

                describe("the first section") {
                    var cell: TextFieldCell? = nil
                    let indexPath = NSIndexPath(forRow: 0, inSection: 0)

                    it("should have 1 row") {
                        expect(subject.tableView.numberOfRowsInSection(0)).to(equal(1))
                    }

                    it("should be titled 'Title'") {
                        expect(subject.tableView(subject.tableView, titleForHeaderInSection: 0)).to(equal("Title"))
                    }

                    it("should not be editable") {
                        expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)) == false
                    }

                    context("when the feed has no title preconfigured") {
                        beforeEach {
                            subject.feed = otherFeed

                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath) as? TextFieldCell
                        }

                        it("should have a placeholder inviting the user to create a title") {
                            expect(cell?.textField.placeholder).to(equal("Enter a title"))
                        }
                    }

                    context("when the feed has a tag that starts with '~'") {
                        beforeEach {
                            subject.feed = Feed(title: "a title", url: nil, summary: "", query: "a query",
                                tags: ["~custom title"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath) as? TextFieldCell
                        }

                        it("should use that tag as the title, minus the leading '~'") {
                            expect(cell?.textField.text).to(equal("custom title"))
                        }
                    }

                    context("when the feed has a title preconfigured") {
                        beforeEach {
                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath) as? TextFieldCell
                        }

                        it("should have a label title equal to the feed's") {
                            expect(cell?.textField.text).to(equal(feed.title))
                        }
                    }

                    describe("the cell") {
                        beforeEach {
                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath) as? TextFieldCell
                        }

                        describe("on change") {
                            beforeEach {
                                cell?.onTextChange?("a title")
                            }

                            itBehavesLike("saving data") {
                                return [
                                    "title": "a title",
                                    "summary": feed.summary,
                                    "query": feed.query ?? "",
                                    "create": false,
                                ]
                            }
                        }

                        it("should have no edit actions") {
                            let editActions = subject.tableView(subject.tableView,
                                editActionsForRowAtIndexPath: indexPath)
                            expect(editActions).to(beNil())
                        }
                    }
                }

                describe("the second section") {
                    var cell: TextFieldCell? = nil
                    let indexPath = NSIndexPath(forRow: 0, inSection: 1)

                    it("should have 1 row") {
                        expect(subject.tableView.numberOfRowsInSection(1)).to(equal(1))
                    }

                    it("should be titled 'Summary'") {
                        expect(subject.tableView(subject.tableView, titleForHeaderInSection: 1)).to(equal("Summary"))
                    }

                    it("should not be editable") {
                        expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)) == false
                    }

                    context("when the feed has no summary preconfigured") {
                        beforeEach {
                            subject.feed = otherFeed
                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath) as? TextFieldCell
                        }

                        it("should invite the user to set the summary") {
                            expect(cell?.textField.placeholder).to(equal("Enter a summary"))
                        }
                    }

                    context("when the feed has a tag that starts with '_'") {
                        beforeEach {
                            subject.feed = Feed(title: "a title", url: nil, summary: "a summary", query: "a query",
                                tags: ["_custom summary"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath) as? TextFieldCell
                        }

                        it("should use that tag as the title, minus the leading '_'") {
                            expect(cell?.textField.text).to(equal("custom summary"))
                        }
                    }

                    context("when the feed has a summary preconfigured") {
                        beforeEach {
                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath) as? TextFieldCell
                        }

                        it("should have a label title equal to the feed's") {
                            expect(cell?.textField.text).to(equal(feed.summary))
                        }
                    }

                    describe("the cell") {
                        beforeEach {
                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath) as? TextFieldCell
                        }

                        describe("on change") {
                            beforeEach {
                                cell?.onTextChange?("a summary")
                            }

                            itBehavesLike("saving data") {
                                return [
                                    "title": feed.title,
                                    "summary": "a summary",
                                    "query": feed.query ?? "",
                                    "create": false,
                                ]
                            }
                        }

                        it("should have no edit actions") {
                            let editActions = subject.tableView(subject.tableView,
                                editActionsForRowAtIndexPath: indexPath)
                            expect(editActions).to(beNil())
                        }
                    }
                }

                describe("the third section") {
                    var cell: TextViewCell? = nil
                    let indexPath = NSIndexPath(forRow: 0, inSection: 2)
                    it("should have 1 row") {
                        expect(subject.tableView.numberOfRowsInSection(2)).to(equal(1))
                    }

                    it("should be titled 'Query'") {
                        expect(subject.tableView(subject.tableView, titleForHeaderInSection: 2)).to(equal("Query"))
                    }

                    it("should be editable") {
                        expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)) == true
                    }

                    describe("the cell") {
                        beforeEach {
                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath) as? TextViewCell
                        }

                        it("should have a label title equal to the feed's") {
                            expect(cell?.textView.text).to(equal(feed.query))
                        }

                        describe("on change") {
                            beforeEach {
                                cell?.onTextChange?("a query")
                            }

                            itBehavesLike("saving data") {
                                return [
                                    "title": feed.title,
                                    "summary": feed.summary,
                                    "query": "a query",
                                    "create": false,
                                ]
                            }
                        }

                        describe("edit actions") {
                            var editActions: [UITableViewRowAction] = []
                            beforeEach {
                                editActions = subject.tableView(subject.tableView,
                                    editActionsForRowAtIndexPath: indexPath) ?? []
                            }

                            it("should have 1 edit action") {
                                expect(editActions.count).to(equal(1))
                            }

                            describe("the action") {
                                var action: UITableViewRowAction? = nil

                                beforeEach {
                                    action = editActions.first
                                }

                                it("should be titled 'Preview'") {
                                    expect(action?.title).to(equal("Preview"))
                                }

                                it("should show a preview of all articles it captures when tapped") {
                                    action?.handler()(action, indexPath)
                                    expect(navigationController.topViewController).to(beAnInstanceOf(ArticleListController.self))
                                    if let articleList = navigationController.topViewController as? ArticleListController {
                                        expect(articleList.previewMode) == true
                                        // TODO: fake articles
                                    }
                                }
                            }
                        }
                    }
                }

                describe("the fourth section") {
                    it("should have n+1 rows") {
                        expect(subject.tableView.numberOfRowsInSection(3)).to(equal(feed.tags.count + 1))
                    }

                    it("should be titled 'Tags'") {
                        expect(subject.tableView(subject.tableView, titleForHeaderInSection: 3)).to(equal("Tags"))
                    }

                    describe("the first row") {
                        var cell: UITableViewCell? = nil
                        let tagIndex: Int = 0
                        let indexPath = NSIndexPath(forRow: 0, inSection: 3)

                        beforeEach {
                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath)
                        }

                        it("should be titled for the row") {
                            expect(cell?.textLabel?.text).to(equal(feed.tags[tagIndex]))
                        }

                        it("should be editable") {
                            expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: NSIndexPath(forRow: tagIndex, inSection: 3))) == true
                        }

                        describe("edit actions") {
                            var editActions: [UITableViewRowAction] = []
                            beforeEach {
                                editActions = subject.tableView(subject.tableView,
                                    editActionsForRowAtIndexPath: indexPath) ?? []
                            }

                            it("should have 2 edit actions") {
                                expect(editActions.count).to(equal(2))
                            }

                            describe("the first action") {
                                var action: UITableViewRowAction! = nil

                                beforeEach {
                                    action = editActions.first
                                }

                                it("should is titled 'Delete'") {
                                    expect(action.title).to(equal("Delete"))
                                }

                                it("should removes the tag when tapped") {
                                    let tag = feed.tags[tagIndex]
                                    action.handler()(action, NSIndexPath(forRow: tagIndex, inSection: 3))
                                    expect(feed.tags).toNot(contain(tag))
                                }
                            }

                            describe("the second action") {
                                var action: UITableViewRowAction! = nil

                                beforeEach {
                                    action = editActions.last
                                }

                                it("should is titled 'Edit'") {
                                    expect(action.title).to(equal("Edit"))
                                }

                                it("should removes the tag when tapped") {
                                    action.handler()(action, NSIndexPath(forRow: tagIndex, inSection: 3))
                                    expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
                                    if let tagEditor = navigationController.topViewController as? TagEditorViewController {
                                        expect(tagEditor.tagIndex).to(equal(tagIndex))
                                        expect(tagEditor.feed).to(equal(feed))
                                    }
                                }
                            }
                        }
                    }

                    describe("the last row") {
                        var cell: UITableViewCell? = nil
                        var indexPath: NSIndexPath! = nil

                        beforeEach {
                            indexPath = NSIndexPath(forRow: feed.tags.count, inSection: 3)
                            cell = subject.tableView(subject.tableView,
                                cellForRowAtIndexPath: indexPath)
                        }

                        it("should be titled 'Add Tag'") {
                            expect(cell?.textLabel?.text).to(equal("Add Tag"))
                        }

                        it("should not be editable") {
                            expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)) == false
                        }

                        describe("when tapped") {
                            beforeEach {
                                subject.tableView(subject.tableView, didSelectRowAtIndexPath: indexPath)
                            }

                            it("should bring up the tag editor screen") {
                                expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
                                if let tagEditor = navigationController.topViewController as? TagEditorViewController {
                                    expect(tagEditor.tagIndex).to(beNil())
                                    expect(tagEditor.feed).to(equal(feed))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
