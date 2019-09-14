import Quick
import Nimble
import Tethys

class FakeFeedDetailViewDelegate: FeedDetailViewDelegate {
    var urlDidChangeCallCount = 0
    private var urlDidChangeArgs: [(FeedDetailView, URL)] = []
    func urlDidChangeArgsForCall(_ callIndex: Int) -> (FeedDetailView, URL) {
        return self.urlDidChangeArgs[callIndex]
    }
    func feedDetailView(_ feedDetailView: FeedDetailView, urlDidChange url: URL) {
        self.urlDidChangeArgs.append((feedDetailView, url))
        self.urlDidChangeCallCount += 1
    }

    var tagsDidChangeCallCount = 0
    private var tagsDidChangeArgs: [(FeedDetailView, [String])] = []
    func tagsDidChangeArgsForCall(_ callIndex: Int) -> (FeedDetailView, [String]) {
        return self.tagsDidChangeArgs[callIndex]
    }
    func feedDetailView(_ feedDetailView: FeedDetailView, tagsDidChange tags: [String]) {
        self.tagsDidChangeCallCount += 1
        self.tagsDidChangeArgs.append((feedDetailView, tags))
    }

    var editTagCallCount = 0
    private var editTagArgs: [(FeedDetailView, String?, (String) -> (Void))] = []
    func editTagArgsForCall(_ callIndex: Int) -> (FeedDetailView, String?, (String) -> (Void)) {
        return self.editTagArgs[callIndex]
    }
    func feedDetailView(_ feedDetailView: FeedDetailView, editTag tag: String?, completion: @escaping (String) -> (Void)) {
        self.editTagCallCount += 1
        self.editTagArgs.append((feedDetailView, tag, completion))
    }
}

class FeedDetailViewSpec: QuickSpec {
    override func spec() {
        var subject: FeedDetailView!
        var delegate: FakeFeedDetailViewDelegate!

        var tableView: UITableView!

        beforeEach {
            delegate = FakeFeedDetailViewDelegate()
            subject = FeedDetailView(forAutoLayout: ())

            subject.delegate = delegate
            tableView = subject.tagsList.tableView
        }

        describe("the theme") {
            it("sets the background color") {
                expect(subject.backgroundColor).to(equal(Theme.backgroundColor))
            }

            it("sets the titleLabel text color") {
                expect(subject.titleLabel.textColor).to(equal(Theme.textColor))
            }

            it("sets the summaryLabel's text color") {
                expect(subject.summaryLabel.textColor).to(equal(Theme.textColor))
            }

            it("sets the addTagButton's title color") {
                expect(subject.addTagButton.titleColor(for: .normal)).to(equal(Theme.highlightColor))
            }
        }

        describe("configure(title:url:summary:tags:)") {
            let tags = ["hello", "goodbye"]
            beforeEach {
                subject.configure(title: "title", url: URL(string: "https://example.com")!, summary: "summary", tags: tags)
            }

            it("sets the titleLabel's text") {
                expect(subject.titleLabel.text) == "title"
            }

            it("sets the urlField's text") {
                expect(subject.urlField.text) == "https://example.com"
            }

            it("sets the summaryLabel's text") {
                expect(subject.summaryLabel.text) == "summary"
            }

            it("sets the tagsList's cells") {
                expect(tableView.numberOfRows(inSection: 0)) == tags.count

                for (idx, tag) in tags.enumerated() {
                    let indexPath = IndexPath(row: idx, section: 0)
                    let cell = tableView.dataSource?.tableView(tableView, cellForRowAt: indexPath)
                    expect(cell?.textLabel?.text) == tag
                }
            }

            it("doesn't call the delegate over the url field text changing") {
                expect(delegate.urlDidChangeCallCount) == 0
            }
        }

        describe("the urlField's delegate") {
            it("calls the delegate whenever the characters change and produce a valid url") {
                _ = subject.urlField.delegate?.textField?(subject.urlField,
                                                          shouldChangeCharactersIn: NSRange(location: 0, length: 0),
                                                          replacementString: "https://example.com")
                expect(delegate.urlDidChangeCallCount) == 1
                guard delegate.urlDidChangeCallCount == 1 else { return }
                let args = delegate.urlDidChangeArgsForCall(0)
                expect(args.0) === subject
                expect(args.1) == URL(string: "https://example.com")
            }

            it("doesn't call the delegate if the characters produce an invalid url") {
                _ = subject.urlField.delegate?.textField?(subject.urlField,
                                                          shouldChangeCharactersIn: NSRange(location: 0, length: 0),
                                                          replacementString: "hello")
                expect(delegate.urlDidChangeCallCount) == 0
            }
        }

        describe("the tagsList") {
            let tags = ["hello", "goodbye"]
            beforeEach {
                subject.configure(title: "", url: URL(string: "https://example.com")!, summary: "", tags: tags)
            }

            it("has a cell for each tag") {
                expect(tableView.numberOfRows(inSection: 0)) == tags.count
            }

            describe("a cell") {
                let indexPath = IndexPath(row: 0, section: 0)

                describe("the contextual actions") {
                    var swipeActions: UISwipeActionsConfiguration? = nil
                    var completionHandlerCalls: [Bool] = []

                    beforeEach {
                        completionHandlerCalls = []
                        swipeActions = tableView.delegate?.tableView?(tableView, trailingSwipeActionsConfigurationForRowAt: indexPath)
                    }

                    it("automatically performs the first action if full swipe") {
                        expect(swipeActions?.performsFirstActionWithFullSwipe).to(beTrue())
                    }

                    it("has two actions") {
                        expect(swipeActions?.actions).to(haveCount(2))
                    }

                    describe("the first action") {
                        var action: UIContextualAction?

                        beforeEach {
                            action = swipeActions?.actions.first
                        }

                        it("is titled 'Delete'") {
                            expect(action?.title) == "Delete"
                        }

                        describe("when tapped") {
                            beforeEach {
                                action?.handler(action!, subject, { completionHandlerCalls.append($0) })
                            }

                            it("deletes the cell from the tags list") {
                                expect(tableView.numberOfRows(inSection: 0)) == (tags.count - 1)
                                let newCell = tableView.dataSource?.tableView(tableView, cellForRowAt: indexPath)
                                expect(newCell?.textLabel?.text) == tags[1]
                            }

                            it("informs the delegate that the tags changed") {
                                expect(delegate.tagsDidChangeCallCount) == 1
                                guard delegate.tagsDidChangeCallCount == 1 else { return }

                                let args = delegate.tagsDidChangeArgsForCall(0)
                                expect(args.0) === subject
                                expect(args.1) == ["goodbye"]
                            }

                            it("calls the completion handler") {
                                expect(completionHandlerCalls).to(equal([true]))
                            }
                        }
                    }

                    describe("the second edit action") {
                        var action: UIContextualAction?

                        beforeEach {
                            action = swipeActions?.actions.last
                        }

                        it("is titled 'Edit'") {
                            expect(action?.title) == "Edit"
                        }

                        describe("when tapped") {
                            beforeEach {
                                action?.handler(action!, subject, { completionHandlerCalls.append($0) })
                            }

                            it("informs its delegate when tapped") {
                                expect(delegate.editTagCallCount) == 1

                                guard delegate.editTagCallCount == 1 else { return }

                                let args = delegate.editTagArgsForCall(0)
                                expect(args.0) === subject
                                expect(args.1) == tags[0]
                            }

                            it("does not yet call the completion handler") {
                                expect(completionHandlerCalls).to(beEmpty())
                            }

                            describe("when the delegate calls the callback") {
                                beforeEach {
                                    guard delegate.editTagCallCount == 1 else {
                                        fail("delegate not called")
                                        return
                                    }

                                    let callback = delegate.editTagArgsForCall(0).2
                                    callback("callback string")
                                }

                                it("replaces the text of the cell with the text the user gave") {
                                    expect(tableView.numberOfRows(inSection: 0)) == 2

                                    let newCell = tableView.dataSource?.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0))
                                    expect(newCell?.textLabel?.text) == "callback string"

                                    let oldCell = tableView.dataSource?.tableView(tableView, cellForRowAt: IndexPath(row: 1, section: 0))
                                    expect(oldCell?.textLabel?.text) == "goodbye"
                                }

                                it("calls the delegate to inform it that the user changed the tags") {
                                    expect(delegate.tagsDidChangeCallCount) == 1
                                    guard delegate.tagsDidChangeCallCount == 1 else { return }
                                    
                                    let args = delegate.tagsDidChangeArgsForCall(0)
                                    expect(args.0) === subject
                                    expect(args.1) == ["callback string", "goodbye"]
                                }

                                it("calls the completion handler") {
                                    expect(completionHandlerCalls).to(equal([true]))
                                }
                            }
                        }
                    }
                }

                describe("tapping the cell") {
                    beforeEach {
                        tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)
                    }

                    it("informs the delegate that the user wants to edit a tag") {
                        expect(delegate.editTagCallCount) == 1

                        guard delegate.editTagCallCount == 1 else { return }

                        let args = delegate.editTagArgsForCall(0)
                        expect(args.0) === subject
                        expect(args.1) == tags[0]
                    }

                    describe("when the delegate calls the callback") {
                        beforeEach {
                            guard delegate.editTagCallCount == 1 else {
                                fail("delegate not called")
                                return
                            }

                            let callback = delegate.editTagArgsForCall(0).2
                            callback("callback string")
                        }

                        it("replaces the text of the cell with the text the user gave") {
                            expect(tableView.numberOfRows(inSection: 0)) == 2

                            let newCell = tableView.dataSource?.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0))
                            expect(newCell?.textLabel?.text) == "callback string"

                            let oldCell = tableView.dataSource?.tableView(tableView, cellForRowAt: IndexPath(row: 1, section: 0))
                            expect(oldCell?.textLabel?.text) == "goodbye"
                        }

                        it("calls the delegate to inform it that the user changed the tags") {
                            expect(delegate.tagsDidChangeCallCount) == 1
                            guard delegate.tagsDidChangeCallCount == 1 else { return }

                            let args = delegate.tagsDidChangeArgsForCall(0)
                            expect(args.0) === subject
                            expect(args.1) == ["callback string", "goodbye"]
                        }
                    }
                }
            }
        }

        describe("the add tag button") {
            let tags = ["hello", "goodbye"]
            beforeEach {
                subject.configure(title: "", url: URL(string: "https://example.com")!, summary: "", tags: tags)
            }

            it("is titled 'Add Tag'") {
                expect(subject.addTagButton.title(for: .normal)) == "Add Tag"
            }

            describe("tapping it") {
                beforeEach {
                    subject.addTagButton.sendActions(for: .touchUpInside)
                }

                it("informs the delegate to create a new tag") {
                    expect(delegate.editTagCallCount) == 1

                    guard delegate.editTagCallCount == 1 else { return }

                    let args = delegate.editTagArgsForCall(0)
                    expect(args.0) === subject
                    expect(args.1).to(beNil())
                }

                describe("when the delegate calls the callback") {
                    beforeEach {
                        guard delegate.editTagCallCount == 1 else {
                            fail("delegate not called")
                            return
                        }

                        let callback = delegate.editTagArgsForCall(0).2
                        callback("callback string")
                    }

                    it("adds another cell to the tags list") {
                        expect(tableView.numberOfRows(inSection: 0)) == 3

                        guard tableView.numberOfRows(inSection: 0) == 3 else { return }
                        let newCell = tableView.dataSource?.tableView(tableView, cellForRowAt: IndexPath(row: 2, section: 0))
                        expect(newCell?.textLabel?.text) == "callback string"
                    }

                    it("calls the delegate to inform that the user added a tag") {
                        expect(delegate.tagsDidChangeCallCount) == 1
                        guard delegate.tagsDidChangeCallCount == 1 else { return }

                        let args = delegate.tagsDidChangeArgsForCall(0)
                        expect(args.0) === subject
                        expect(args.1) == ["hello", "goodbye", "callback string"]
                    }

                }
            }
        }
    }
}
