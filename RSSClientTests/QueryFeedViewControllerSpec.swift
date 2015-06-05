import Quick
import Nimble
import rNews
import Ra
import Robot

class QueryFeedViewControllerSpec: QuickSpec {
    override func spec() {
        var feed = Feed(title: "title", url: nil, summary: "summary", query: "",
            tags: ["a", "b", "c"], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
        let otherFeed = Feed(title: "", url: nil, summary: "", query: "",
            tags: ["a", "b", "c"], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)

        var navigationController: UINavigationController!
        var subject: QueryFeedViewController! = nil
        var injector: Injector! = nil
        var dataManager: DataManagerMock! = nil

        var backgroundQueue: FakeOperationQueue! = nil
        var window: UIWindow! = nil
        var presentingController: UIViewController! = nil

        beforeEach {
            injector = Injector()

            backgroundQueue = FakeOperationQueue()
            backgroundQueue.runSynchronously = true
            injector.bind(kBackgroundQueue, to: backgroundQueue)

            dataManager = DataManagerMock()
            injector.bind(DataManager.self, to: dataManager)

            subject = injector.create(QueryFeedViewController.self) as! QueryFeedViewController

            navigationController = UINavigationController(rootViewController: subject)

            window = UIWindow()
            presentingController = UIViewController()
            window.rootViewController = presentingController
            window.makeKeyAndVisible()
            RBTimeLapse.advanceMainRunLoop()
            presentingController.presentViewController(navigationController, animated: false, completion: nil)

            feed = Feed(title: "title", url: NSURL(string: "http://example.com/feed"), summary: "summary", query: nil,
                tags: ["a", "b", "c"], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)

            subject.feed = feed

            subject.view.layoutIfNeeded()
            RBTimeLapse.advanceMainRunLoop()
        }

        it("should have a save button") {
            expect(subject.navigationItem.rightBarButtonItem?.title).to(equal("Save"))
        }

        describe("tapping 'save'") {
            beforeEach {
                let saveButton = subject.navigationItem.rightBarButtonItem
                saveButton?.tap()
            }

            it("should save the changes to the dataManager") {
                expect(dataManager.lastSavedFeed).to(equal(feed))
            }

            it("should dismiss itself") {
                expect(presentingController.presentedViewController).to(beNil())
            }
        }

        it("should have a dismiss button") {
            expect(subject.navigationItem.leftBarButtonItem?.title).to(equal("Dismiss"))
        }

        describe("tapping 'dismiss'") {
            beforeEach {
                let dismissButton = subject.navigationItem.leftBarButtonItem
                dismissButton?.tap()
            }

            it("should dismiss itself") {
                expect(presentingController.presentedViewController).to(beNil())
            }
        }

        describe("the tableView") {
            it("should should have 4 sections") {
                expect(subject.tableView.numberOfSections()).to(equal(4))
            }

            describe("the first section") {
                it("should have 1 row") {
                    expect(subject.tableView.numberOfRowsInSection(0)).to(equal(1))
                }

                it("should be titled 'Title'") {
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 0)).to(equal("Title"))
                }

                it("should not be editable") {
                    expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 0))).to(beFalsy())
                }

                describe("the cell") {
                    var cell: TextFieldCell? = nil
                    context("when the feed has no title preconfigured") {
                        beforeEach {
                            subject.feed = otherFeed
                            subject.view.layoutIfNeeded()
                            RBTimeLapse.advanceMainRunLoop()

                            cell = subject.tableView.visibleCells().first as? TextFieldCell
                        }

                        it("should have a label title 'No title available'") {
                            expect(cell?.textLabel?.text).to(equal("No title available"))
                        }

                        it("should re-color the text gray") {
                            expect(cell?.textLabel?.textColor).to(equal(UIColor.grayColor()))
                        }
                    }

                    context("when the feed has a title preconfigured") {
                        beforeEach {
                            cell = subject.tableView.visibleCells().first as? TextFieldCell
                        }

                        it("should have a label title equal to the feed's") {
                            expect(cell?.textLabel?.text).to(equal(feed.title))
                        }
                    }

                    describe("the cell") {
                        beforeEach {
                            cell = subject.tableView.visibleCells().first as? TextFieldCell
                        }

                        describe("on change") {
                            beforeEach {
                                let range = NSMakeRange(0, 7)
                                if let textField = cell?.textField {
                                    cell?.textField(textField, shouldChangeCharactersInRange: range, replacementString: "a title")
                                }
                            }

                            it("should change the feed's title") {
                                expect(feed.summary).to(equal("a title"))
                            }
                        }
                    }
                }
            }

            describe("the second section") {
                var cell: TextFieldCell? = nil

                it("should have 1 row") {
                    expect(subject.tableView.numberOfRowsInSection(1)).to(equal(1))
                }

                it("should be titled 'Summary'") {
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 0)).to(equal("Summary"))
                }

                it("should not be editable") {
                    expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 1))).to(beFalsy())
                }

                context("when the feed has no summary preconfigured") {
                    beforeEach {
                        subject.feed = otherFeed
                        subject.view.layoutIfNeeded()
                        RBTimeLapse.advanceMainRunLoop()

                        if (subject.tableView.visibleCells().count >= 2) {
                            cell = subject.tableView.visibleCells()[1] as? TextFieldCell
                        }
                    }

                    it("should have a label title 'No summary available'") {
                        expect(cell?.textLabel?.text).to(equal("No summary available"))
                    }

                    it("should re-color the text gray") {
                        expect(cell?.textLabel?.textColor).to(equal(UIColor.grayColor()))
                    }
                }

                context("when the feed has a summary preconfigured") {
                    beforeEach {
                        if (subject.tableView.visibleCells().count >= 2) {
                            cell = subject.tableView.visibleCells()[1] as? TextFieldCell
                        }
                    }

                    it("should have a label title equal to the feed's") {
                        expect(cell?.textLabel?.text).to(equal(feed.summary))
                    }
                }

                describe("the cell") {
                    beforeEach {
                        if (subject.tableView.visibleCells().count >= 2) {
                            cell = subject.tableView.visibleCells()[1] as? TextFieldCell
                        }
                    }

                    describe("on change") {
                        beforeEach {
                            let range = NSMakeRange(0, 9)
                            if let textField = cell?.textField {
                                cell?.textField(textField, shouldChangeCharactersInRange: range, replacementString: "a summary")
                            }
                        }

                        it("should change the feed's summary") {
                            expect(feed.summary).to(equal("a summary"))
                        }
                    }
                }
            }

            describe("the third section") {
                var cell: TextFieldCell? = nil
                it("should have 1 row") {
                    expect(subject.tableView.numberOfRowsInSection(2)).to(equal(1))
                }

                it("should be titled 'Query'") {
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 0)).to(equal("Title"))
                }

                it("should be editable") {
                    expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 2))).to(beTruthy())
                }

                describe("the cell") {
                    beforeEach {
                        if (subject.tableView.visibleCells().count >= 2) {
                            cell = subject.tableView.visibleCells()[2] as? TextFieldCell
                        }
                    }

                    it("should have a label title equal to the feed's") {
                        expect(cell?.textLabel?.text).to(equal(feed.query))
                    }

                    describe("on change") {
                        beforeEach {
                            let range = NSMakeRange(0, 9)
                            if let textField = cell?.textField {
                                cell?.textField(textField, shouldChangeCharactersInRange: range, replacementString: "a summary")
                            }
                        }

                        it("should change the feed's query") {
                            expect(feed.summary).to(equal("a summary"))
                        }
                    }

                    describe("edit actions") {
                        var editActions: [UITableViewRowAction] = []
                        beforeEach {
                            editActions = subject.tableView(subject.tableView,
                                editActionsForRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 2)) as? [UITableViewRowAction] ?? []
                        }

                        it("should have 1 edit action") {
                            expect(editActions.count).to(equal(1))
                        }

                        describe("the action") {
                            var action: UITableViewRowAction! = nil

                            beforeEach {
                                action = editActions.first
                            }

                            it("should be titled 'Preview'") {
                                expect(action.title).to(equal("Preview"))
                            }

                            it("should show a preview of all articles it captures when tapped") {
                                action.handler()(action, NSIndexPath(forRow: 0, inSection: 2))
                                RBTimeLapse.advanceMainRunLoop()
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

//            describe("the fourth section") {
//                it("should have n+1 rows") {
//                    expect(subject.tableView.numberOfRowsInSection(3)).to(equal(feed.tags.count + 1))
//                }
//
//                it("should be titled 'Tags'") {
//                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 0)).to(equal("Title"))
//                }
//
//                describe("the first row") {
//                    var cell: UITableViewCell! = nil
//                    let tagIndex: Int = 0
//
//                    beforeEach {
//                        cell = subject.tableView.visibleCells()[3] as! UITableViewCell
//                    }
//
//                    it("should be titled for the row") {
//                        expect(cell.textLabel?.text).to(equal(feed.tags[tagIndex]))
//                    }
//
//                    it("should be editable") {
//                        expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: NSIndexPath(forRow: tagIndex, inSection: 3))).to(beTruthy())
//                    }
//
//                    describe("edit actions") {
//                        var editActions: [UITableViewRowAction] = []
//                        beforeEach {
//                            editActions = subject.tableView(subject.tableView,
//                                editActionsForRowAtIndexPath: NSIndexPath(forRow: tagIndex, inSection: 3)) as? [UITableViewRowAction] ?? []
//                        }
//
//                        it("should have 2 edit actions") {
//                            expect(editActions.count).to(equal(2))
//                        }
//
//                        describe("the first action") {
//                            var action: UITableViewRowAction! = nil
//
//                            beforeEach {
//                                action = editActions.first
//                            }
//
//                            it("should is titled 'Delete'") {
//                                expect(action.title).to(equal("Delete"))
//                            }
//
//                            it("should removes the tag when tapped") {
//                                let tag = feed.tags[tagIndex]
//                                action.handler()(action, NSIndexPath(forRow: tagIndex, inSection: 3))
//                                expect(feed.tags).toNot(contain(tag))
//                            }
//                        }
//
//                        describe("the second action") {
//                            var action: UITableViewRowAction! = nil
//
//                            beforeEach {
//                                action = editActions.last
//                            }
//
//                            it("should is titled 'Edit'") {
//                                expect(action.title).to(equal("Edit"))
//                            }
//
//                            it("should removes the tag when tapped") {
//                                action.handler()(action, NSIndexPath(forRow: tagIndex, inSection: 3))
//                                RBTimeLapse.advanceMainRunLoop()
//                                expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
//                                if let tagEditor = navigationController.topViewController as? TagEditorViewController {
//                                    expect(tagEditor.tagIndex).to(equal(tagIndex))
//                                    expect(tagEditor.feed).to(equal(feed))
//                                }
//                            }
//                        }
//                    }
//                }
//
//                describe("the last row") {
//                    var cell: UITableViewCell! = nil
//                    var indexPath: NSIndexPath! = nil
//
//                    beforeEach {
//                        indexPath = NSIndexPath(forRow: feed.tags.count, inSection: 3)
//                        cell = subject.tableView.visibleCells().last as! UITableViewCell
//                    }
//                    
//                    it("should be titled 'Add Tag'") {
//                        expect(cell.textLabel?.text).to(equal("Add Tag"))
//                    }
//                    
//                    it("should not be editable") {
//                        expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)).to(beFalsy())
//                    }
//                    
//                    describe("when tapped") {
//                        beforeEach {
//                            subject.tableView(subject.tableView, didSelectRowAtIndexPath: indexPath)
//                        }
//                        
//                        it("should bring up the tag editor screen") {
//                            RBTimeLapse.advanceMainRunLoop()
//                            expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
//                            if let tagEditor = navigationController.topViewController as? TagEditorViewController {
//                                expect(tagEditor.tagIndex).to(beNil())
//                                expect(tagEditor.feed).to(equal(feed))
//                            }
//                        }
//                    }
//                }
//            }
        }
    }
}
