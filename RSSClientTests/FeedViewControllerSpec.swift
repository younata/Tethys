import Quick
import Nimble
import rNews
import Ra
import Robot
import rNewsKit

class FeedViewControllerSpec: QuickSpec {
    override func spec() {
        var feed = Feed(title: "title", url: NSURL(string: "http://example.com/feed"), summary: "summary", query: nil,
            tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
        let otherFeed = Feed(title: "", url: NSURL(string: "http://example.com/feed"), summary: "", query: nil,
            tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

        var navigationController: UINavigationController!
        var subject: FeedViewController! = nil
        var injector: Injector! = nil
        var dataReadWriter: FakeDataReadWriter! = nil

        var urlSession: FakeURLSession! = nil
        var backgroundQueue: FakeOperationQueue! = nil
        var window: UIWindow! = nil
        var presentingController: UIViewController! = nil

        beforeEach {
            injector = Injector()

            urlSession = FakeURLSession()
            injector.bind(NSURLSession.self, to: urlSession)

            backgroundQueue = FakeOperationQueue()
            backgroundQueue.runSynchronously = true
            injector.bind(kBackgroundQueue, to: backgroundQueue)

            dataReadWriter = FakeDataReadWriter()
            injector.bind(DataRetriever.self, to: dataReadWriter)
            injector.bind(DataWriter.self, to: dataReadWriter)

            subject = injector.create(FeedViewController.self) as! FeedViewController

            navigationController = UINavigationController(rootViewController: subject)

            window = UIWindow()
            presentingController = UIViewController()
            window.rootViewController = presentingController
            RBTimeLapse.advanceMainRunLoop()
            presentingController.presentViewController(navigationController, animated: false, completion: nil)

            feed = Feed(title: "title", url: NSURL(string: "http://example.com/feed"), summary: "summary", query: nil,
                tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            subject.feed = feed

            subject.view.layoutIfNeeded()
            RBTimeLapse.advanceMainRunLoop()
        }

        afterEach {
            window.hidden = true
            window = nil
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
                expect(dataReadWriter.lastSavedFeed).to(equal(feed))
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
                expect(subject.tableView.numberOfSections).to(equal(4))
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
                    var cell: UITableViewCell! = nil
                    context("when the feed has no title preconfigured") {
                        beforeEach {
                            subject.feed = otherFeed
                            subject.view.layoutIfNeeded()
                            RBTimeLapse.advanceMainRunLoop()

                            cell = subject.tableView.visibleCells[0]
                        }

                        it("should have a label title 'No title available'") {
                            expect(cell.textLabel?.text).to(equal("No title available"))
                        }

                        it("should re-color the text gray") {
                            expect(cell.textLabel?.textColor).to(equal(UIColor.grayColor()))
                        }
                    }

                    context("when the feed has a tag that starts with '~'") {
                        beforeEach {
                            subject.feed = Feed(title: "a title", url: NSURL(string: ""), summary: "", query: nil,
                                tags: ["~custom title"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                            subject.view.layoutIfNeeded()
                            RBTimeLapse.advanceMainRunLoop()

                            cell = subject.tableView.visibleCells[0]
                        }

                        it("should use that tag as the title, minus the leading '~'") {
                            expect(cell.textLabel?.text).to(equal("custom title"))
                        }
                    }

                    context("when the feed has a title preconfigured") {
                        beforeEach {
                            cell = subject.tableView.visibleCells[0]
                        }

                        it("should have a label title equal to the feed's") {
                            expect(cell.textLabel?.text).to(equal(feed.title))
                        }
                    }
                }
            }

            describe("the second section") {
                it("should have 1 row") {
                    expect(subject.tableView.numberOfRowsInSection(1)).to(equal(1))
                }

                it("should be titled 'URL'") {
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 1)).to(equal("URL"))
                }

                it("should not be editable") {
                    expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 1))).to(beFalsy())
                }

                describe("the cell") {
                    var cell: TextFieldCell! = nil
                    beforeEach {
                        cell = subject.tableView.visibleCells[1] as! TextFieldCell
                    }

                    it("should be preconfigured with the feed's url") {
                        expect(cell.textField.text).to(equal(feed.url?.absoluteString))
                    }

                    describe("on change") {
                        beforeEach {
                            let range = NSMakeRange(0, 23)
                            cell.textField(cell.textField, shouldChangeCharactersInRange: range, replacementString: "http://example.com/feed")
                        }

                        it("should make a request to the url") {
                            let urlString = urlSession.lastURL?.absoluteString
                            expect(urlString).to(equal("http://example.com/feed"))
                        }

                        context("when the request succeeds") {
                            let urlResponse = NSHTTPURLResponse(URL: NSURL(string: "")!, statusCode: 200, HTTPVersion: nil, headerFields: nil)
                            context("if the response (text) is a valid feed") {
                                beforeEach {
                                    let rss = NSBundle(forClass: self.classForCoder).pathForResource("feed2", ofType: "rss")!
                                    let data = NSData(contentsOfFile: rss)
                                    urlSession.lastCompletionHandler(data, urlResponse, nil)
                                }
                                
                                it("should mark the field as valid") {
                                    expect(cell.isValid).to(beTruthy())
                                }
                            }

                            context("if the response is not a valid feed") {
                                beforeEach {
                                    let data = "Hello World".dataUsingEncoding(NSUTF8StringEncoding)
                                    urlSession.lastCompletionHandler(data, urlResponse, nil)
                                }

                                it("should mark the field as invalid") {
                                    expect(cell.isValid).to(beFalsy())
                                }
                            }
                        }

                        context("when the request fails") {
                            beforeEach {
                                urlSession.lastCompletionHandler(nil, nil, NSError(domain: "", code: 0, userInfo: [:]))
                            }

                            it("should mark the field as invalid") {
                                expect(cell.isValid).to(beFalsy())
                            }
                        }
                    }
                }
            }

            describe("the third section") {
                var cell: UITableViewCell! = nil
                it("should have 1 row") {
                    expect(subject.tableView.numberOfRowsInSection(2)).to(equal(1))
                }

                it("should be titled 'Summary'") {
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 2)).to(equal("Summary"))
                }

                it("should not be editable") {
                    expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 2))).to(beFalsy())
                }

                context("when the feed has no summary preconfigured") {
                    beforeEach {
                        subject.feed = otherFeed
                        subject.view.layoutIfNeeded()
                        RBTimeLapse.advanceMainRunLoop()

                        cell = subject.tableView.visibleCells[2]
                    }

                    it("should have a label title 'No summary available'") {
                        expect(cell.textLabel?.text).to(equal("No summary available"))
                    }

                    it("should re-color the text gray") {
                        expect(cell.textLabel?.textColor).to(equal(UIColor.grayColor()))
                    }
                }

                context("when the feed has a tag that starts with '`'") {
                    beforeEach {
                        subject.feed = Feed(title: "a title", url: NSURL(string: ""), summary: "a summary", query: nil,
                            tags: ["`custom summary"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                        subject.view.layoutIfNeeded()
                        RBTimeLapse.advanceMainRunLoop()

                        cell = subject.tableView.visibleCells[2]
                    }

                    it("should use that tag as the summary, minus the leading '`'") {
                        expect(cell.textLabel?.text).to(equal("custom summary"))
                    }
                }

                context("when the feed has a summary preconfigured") {
                    beforeEach {
                        cell = subject.tableView.visibleCells[2]
                    }

                    it("should have a label title equal to the feed's") {
                        expect(cell.textLabel?.text).to(equal(feed.summary))
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
                    var cell: UITableViewCell! = nil
                    let tagIndex: Int = 0

                    beforeEach {
                        cell = subject.tableView.visibleCells[3]
                    }

                    it("should be titled for the row") {
                        expect(cell.textLabel?.text).to(equal(feed.tags[tagIndex]))
                    }

                    it("should be editable") {
                        expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: NSIndexPath(forRow: tagIndex, inSection: 3))).to(beTruthy())
                    }

                    describe("edit actions") {
                        var editActions: [UITableViewRowAction] = []
                        beforeEach {
                            editActions = subject.tableView(subject.tableView,
                                editActionsForRowAtIndexPath: NSIndexPath(forRow: tagIndex, inSection: 3)) ?? []
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
                                RBTimeLapse.advanceMainRunLoop()
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
                    var cell: UITableViewCell! = nil
                    var indexPath: NSIndexPath! = nil

                    beforeEach {
                        indexPath = NSIndexPath(forRow: feed.tags.count, inSection: 3)
                        cell = subject.tableView.visibleCells.last
                    }

                    it("should be titled 'Add Tag'") {
                        expect(cell.textLabel?.text).to(equal("Add Tag"))
                    }

                    it("should not be editable") {
                        expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: indexPath)).to(beFalsy())
                    }

                    describe("when tapped") {
                        beforeEach {
                            subject.tableView(subject.tableView, didSelectRowAtIndexPath: indexPath)
                        }

                        it("should bring up the tag editor screen") {
                            RBTimeLapse.advanceMainRunLoop()
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
