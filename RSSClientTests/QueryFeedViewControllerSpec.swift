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
        var dataReadWriter: FakeDataReadWriter! = nil

        var backgroundQueue: FakeOperationQueue! = nil

        beforeEach {
            injector = Injector()

            backgroundQueue = FakeOperationQueue()
            backgroundQueue.runSynchronously = true
            injector.bind(kBackgroundQueue, to: backgroundQueue)

            dataReadWriter = FakeDataReadWriter()
            injector.bind(DataRetriever.self, to: dataReadWriter)
            injector.bind(DataWriter.self, to: dataReadWriter)

            subject = injector.create(QueryFeedViewController.self) as! QueryFeedViewController

            navigationController = UINavigationController(rootViewController: subject)

            feed = Feed(title: "title", url: nil, summary: "summary", query: "function(article) {return !article.read;}",
                tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            subject.feed = feed

            subject.view.layoutIfNeeded()
        }

        it("should have a save button") {
            expect(subject.navigationItem.rightBarButtonItem?.title).to(equal("Save"))
        }

        describe("tapping 'save'") {
            var presentingController: UIViewController? = nil
            beforeEach {
                presentingController = UIViewController()
                presentingController?.presentViewController(navigationController, animated: false, completion: nil)

                let saveButton = subject.navigationItem.rightBarButtonItem
                saveButton?.tap()
            }

            it("should save the changes to the dataManager") {
                expect(dataReadWriter.lastSavedFeed).to(equal(feed))
            }

            it("should dismiss itself") {
                expect(presentingController?.presentedViewController).to(beNil())
            }
        }

        it("should have a dismiss button") {
            expect(subject.navigationItem.leftBarButtonItem?.title).to(equal("Dismiss"))
        }

        describe("tapping 'dismiss'") {
            var presentingController: UIViewController? = nil
            beforeEach {
                presentingController = UIViewController()
                presentingController?.presentViewController(navigationController, animated: false, completion: nil)

                let dismissButton = subject.navigationItem.leftBarButtonItem
                dismissButton?.tap()
            }

            it("should dismiss itself") {
                expect(presentingController?.presentedViewController).to(beNil())
            }
        }

        describe("the tableView") {
            it("should should have 4 sections") {
                expect(subject.tableView.numberOfSections).to(equal(4))
            }

            describe("the first section") {
                var cell: TextViewCell? = nil
                let indexPath = NSIndexPath(forRow: 0, inSection: 0)

                it("should have 1 row") {
                    expect(subject.tableView.numberOfRowsInSection(0)).to(equal(1))
                }

                it("should be titled 'Title'") {
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 0)).to(equal("Title"))
                }

                it("should not be editable") {
                    expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)).to(beFalsy())
                }

                context("when the feed has no title preconfigured") {
                    beforeEach {
                        subject.feed = otherFeed

                        cell = subject.tableView(subject.tableView,
                            cellForRowAtIndexPath: indexPath) as? TextViewCell
                    }

                    it("should have a label title 'No title available'") {
                        expect(cell?.textView.text).to(equal("No title available"))
                    }

                    it("should re-color the text gray") {
                        expect(cell?.textView.textColor).to(equal(UIColor.grayColor()))
                    }
                }

                context("when the feed has a tag that starts with '~'") {
                    beforeEach {
                        subject.feed = Feed(title: "a title", url: nil, summary: "", query: "a query",
                            tags: ["~custom title"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                        cell = subject.tableView(subject.tableView,
                            cellForRowAtIndexPath: indexPath) as? TextViewCell
                    }

                    it("should use that tag as the title, minus the leading '~'") {
                        expect(cell?.textView.text).to(equal("custom title"))
                    }
                }

                context("when the feed has a title preconfigured") {
                    beforeEach {
                        cell = subject.tableView(subject.tableView,
                            cellForRowAtIndexPath: indexPath) as? TextViewCell
                    }

                    it("should have a label title equal to the feed's") {
                        expect(cell?.textView.text).to(equal(feed.title))
                    }
                }

                describe("the cell") {
                    beforeEach {
                        cell = subject.tableView(subject.tableView,
                            cellForRowAtIndexPath: indexPath) as? TextViewCell
                    }

                    describe("on change") {
                        beforeEach {
                            cell?.textView.text = "a title"
                            if let textView = cell?.textView {
                                cell?.textViewDidChange(textView)
                            }
                        }

                        it("should change the feed's title") {
                            expect(feed.title).to(equal("a title"))
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
                var cell: TextViewCell? = nil
                let indexPath = NSIndexPath(forRow: 0, inSection: 1)

                it("should have 1 row") {
                    expect(subject.tableView.numberOfRowsInSection(1)).to(equal(1))
                }

                it("should be titled 'Summary'") {
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 1)).to(equal("Summary"))
                }

                it("should not be editable") {
                    expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)).to(beFalsy())
                }

                context("when the feed has no summary preconfigured") {
                    beforeEach {
                        subject.feed = otherFeed
                        cell = subject.tableView(subject.tableView,
                            cellForRowAtIndexPath: indexPath) as? TextViewCell
                    }

                    it("should have a label title 'No summary available'") {
                        expect(cell?.textView.text).to(equal("No summary available"))
                    }

                    it("should re-color the text gray") {
                        expect(cell?.textView.textColor).to(equal(UIColor.grayColor()))
                    }
                }

                context("when the feed has a tag that starts with '`'") {
                    beforeEach {
                        subject.feed = Feed(title: "a title", url: nil, summary: "a summary", query: "a query",
                            tags: ["`custom summary"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                        cell = subject.tableView(subject.tableView,
                            cellForRowAtIndexPath: indexPath) as? TextViewCell
                    }

                    it("should use that tag as the title, minus the leading '`'") {
                        expect(cell?.textView.text).to(equal("custom summary"))
                    }
                }

                context("when the feed has a summary preconfigured") {
                    beforeEach {
                        cell = subject.tableView(subject.tableView,
                            cellForRowAtIndexPath: indexPath) as? TextViewCell
                    }

                    it("should have a label title equal to the feed's") {
                        expect(cell?.textView.text).to(equal(feed.summary))
                    }
                }

                describe("the cell") {
                    beforeEach {
                        cell = subject.tableView(subject.tableView,
                            cellForRowAtIndexPath: indexPath) as? TextViewCell
                    }

                    describe("on change") {
                        beforeEach {
                            cell?.textView.text = "a summary"
                            if let textView = cell?.textView {
                                cell?.textViewDidChange(textView)
                            }
                        }

                        it("should change the feed's summary") {
                            expect(feed.summary).to(equal("a summary"))
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
                    expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)).to(beTruthy())
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
                            cell?.textView.text = "a query"
                            if let textView = cell?.textView {
                                cell?.textViewDidChange(textView)
                            }
                        }

                        it("should change the feed's query") {
                            expect(feed.query).to(equal("a query"))
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
                                    expect(articleList.previewMode).to(beTruthy())
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
                        expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: NSIndexPath(forRow: tagIndex, inSection: 3))).to(beTruthy())
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
                        expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)).to(beFalsy())
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
