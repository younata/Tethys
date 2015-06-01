import Quick
import Nimble
import rNews
import Ra

class FeedViewControllerSpec: QuickSpec {
    override func spec() {
        var navigationController: UINavigationController!
        var subject: FeedViewController! = nil
        var injector: Injector! = nil
        var dataManager: DataManagerMock! = nil
        var feed: Feed! = nil
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

            dataManager = DataManagerMock()
            injector.bind(DataManager.self, to: dataManager)

            subject = injector.create(FeedViewController.self) as! FeedViewController

            navigationController = UINavigationController(rootViewController: subject)

            window = UIWindow()
            presentingController = UIViewController()
            window.rootViewController = presentingController
            presentingController.presentViewController(navigationController, animated: false, completion: nil)

            subject.view.layoutIfNeeded()
        }

        fit("should have a save button") {
            expect(subject.navigationItem.leftBarButtonItem?.title).to(equal("Save"))
        }

        fdescribe("tapping 'save'") {
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

        fit("should have a dismiss button") {
            expect(subject.navigationItem.leftBarButtonItem?.title).to(equal("Dismiss"))
        }

        fdescribe("tapping 'dismiss'") {
            beforeEach {
                let dismissButton = subject.navigationItem.leftBarButtonItem
                dismissButton?.tap()
            }

            it("should dismiss itself") {
                expect(presentingController.presentedViewController).to(beNil())
            }
        }

        fdescribe("the tableView") {
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
                    var cell: UITableViewCell! = nil
                    context("when the feed has no title preconfigured") {
                        beforeEach {
                            cell = subject.tableView.visibleCells()[0] as! UITableViewCell
                        }

                        it("should have a label title 'No title available'") {
                            expect(cell.textLabel?.text).to(equal("No title available"))
                        }

                        it("should re-color the text gray") {
                            expect(cell.textLabel?.textColor).to(equal(UIColor.grayColor()))
                        }
                    }

                    context("when the feed has a title preconfigured") {
                        beforeEach {
                            cell = subject.tableView.visibleCells()[0] as! UITableViewCell
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
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 0)).to(equal("Title"))
                }

                it("should not be editable") {
                    expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 1))).to(beFalsy())
                }

                describe("the cell") {
                    var cell: TextFieldCell! = nil
                    beforeEach {
                        cell = subject.tableView.visibleCells()[1] as! TextFieldCell
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
                            context("if the response (text) is a valid feed") {
                                beforeEach {
                                    let rss = NSBundle(forClass: self.classForCoder).pathForResource("feed2", ofType: "rss")!
                                    let data = NSData(contentsOfFile: rss)
                                    urlSession.lastCompletionHandler(data, nil, nil)
                                }
                                
                                it("should mark the field as valid") {
                                    expect(cell.isValid).to(beTruthy())
                                }
                            }

                            context("if the response is not a valid feed") {
                                beforeEach {
                                    let data = "Hello World".dataUsingEncoding(NSUTF8StringEncoding)
                                    urlSession.lastCompletionHandler(data, nil, nil)
                                }

                                it("should mark the field as invalid") {
                                    expect(cell.isValid).to(beFalsy())
                                }
                            }
                        }

                        context("when the request fails") {
                            beforeEach {
                                urlSession.lastCompletionHandler(nil, nil, NSError())
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
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 0)).to(equal("Title"))
                }

                it("should not be editable") {
                    expect(subject.tableView(subject.tableView, canEditRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 2))).to(beFalsy())
                }

                context("when the feed has no summary preconfigured") {
                    beforeEach {
                        cell = subject.tableView.visibleCells()[0] as! UITableViewCell
                    }

                    it("should have a label title 'No summary available'") {
                        expect(cell.textLabel?.text).to(equal("No summary available"))
                    }

                    it("should re-color the text gray") {
                        expect(cell.textLabel?.textColor).to(equal(UIColor.grayColor()))
                    }
                }

                context("when the feed has a summary preconfigured") {
                    beforeEach {
                        cell = subject.tableView.visibleCells()[0] as! UITableViewCell
                    }

                    it("should have a label title equal to the feed's") {
                        expect(cell.textLabel?.text).to(equal(feed.summary))
                    }
                }
            }

            describe("the fourth section") {
                it("should have n+1 rows") {
                    expect(subject.tableView.numberOfRowsInSection(2)).to(equal(feed.tags.count + 1))
                }

                it("should be titled 'Tags'") {
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 0)).to(equal("Title"))
                }
            }
        }
    }
}
