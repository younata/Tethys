import Quick
import Nimble
import Tethys
@testable import TethysKit

class FeedViewControllerSpec: QuickSpec {
    override func spec() {
        var feed: Feed!

        var navigationController: UINavigationController!
        var subject: FeedViewController!
        var feedService: FakeFeedService!

        var rootViewController: UIViewController!
        var themeRepository: ThemeRepository!

        beforeEach {
            feed = Feed(title: "title", url: URL(string: "http://example.com/feed")!, summary: "summary", tags: ["a", "b", "c"], unreadCount: 0, image: nil)

            themeRepository = ThemeRepository(userDefaults: nil)

            feedService = FakeFeedService()
            subject = FeedViewController(
                feed: feed,
                feedService: feedService,
                themeRepository: themeRepository,
                tagEditorViewController: {
                    return tagEditorViewControllerFactory()
                }
            )

            rootViewController = UIViewController()
            navigationController = UINavigationController(rootViewController: rootViewController)
            navigationController.pushViewController(subject, animated: false)

            subject.view.layoutIfNeeded()
        }

        it("has a save button") {
            expect(subject.navigationItem.rightBarButtonItem?.title) == "Save"
        }

        describe("tapping 'save' without making any changes") {
            beforeEach {
                let saveButton = subject.navigationItem.rightBarButtonItem
                saveButton?.tap()
            }

            it("dismisses itself") {
                expect(navigationController.visibleViewController).to(equal(rootViewController))
            }
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("updates the navigation bar styling") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
                expect(convertFromOptionalNSAttributedStringKeyDictionary(subject.navigationController?.navigationBar.titleTextAttributes) as? [String: UIColor]) == [convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): themeRepository.textColor]
            }
        }

        describe("the feedDetailView") {
            it("is configured with the feed's title, url, summary, and tags") {
                expect(subject.feedDetailView.title) == "title"
                expect(subject.feedDetailView.url) == URL(string: "http://example.com/feed")
                expect(subject.feedDetailView.summary) == "summary"
                expect(subject.feedDetailView.tags) == ["a", "b", "c"]
            }
        }

        describe("the feedDetailViewDelegate") {
            describe("feedDetailView(urlDidChange:)") {
                let url = URL(string: "https://example.com/new_feed")!

                beforeEach {
                    subject.feedDetailView.delegate?.feedDetailView(subject.feedDetailView, urlDidChange: url)
                }

                it("does not yet set the feed url to the new url") {
                    expect(feed.url) == URL(string: "http://example.com/feed")
                }

                describe("tapping 'save'") {
                    beforeEach {
                        subject.navigationItem.rightBarButtonItem?.tap()
                    }

                    it("asks the feedService to update the feed's url") {
                        expect(feedService.setURLCalls).to(haveCount(1))

                        guard let call = feedService.setURLCalls.last else { return }

                        expect(call.feed).to(equal(feed))
                        expect(call.url).to(equal(url))
                    }

                    describe("when the call succeeds") {
                        beforeEach {
                            feedService.setURLPromises.last?.resolve(.success(feed))
                        }

                        it("dismisses itself") {
                            expect(navigationController.visibleViewController).to(equal(rootViewController))
                        }
                    }

                    describe("when the call fails") {
                        beforeEach {
                            feedService.setURLPromises.last?.resolve(.failure(.unknown))
                        }

                        it("dismisses itself") {
                            expect(navigationController.visibleViewController).to(equal(rootViewController))
                        }
                    }
                }
            }

            describe("feedDetailView(tagsDidChange:)") {
                let tags = ["d", "e", "f"]

                beforeEach {
                    subject.feedDetailView.delegate?.feedDetailView(subject.feedDetailView, tagsDidChange: tags)
                }

                it("does not yet set the feed tags to the new tags") {
                    expect(feed.tags) == ["a", "b", "c"]
                }

                describe("tapping 'save'") {
                    beforeEach {
                        subject.navigationItem.rightBarButtonItem?.tap()
                    }

                    it("asks the feedService to update the feed's tags") {
                        expect(feedService.setTagsCalls).to(haveCount(1))

                        guard let call = feedService.setTagsCalls.last else { return }

                        expect(call.feed).to(equal(feed))
                        expect(call.tags).to(haveCount(3))
                        expect(call.tags).to(contain("d", "e", "f"))
                    }

                    describe("when the call succeeds") {
                        beforeEach {
                            feedService.setTagsPromises.last?.resolve(.success(feed))
                        }

                        it("dismisses itself") {
                            expect(navigationController.visibleViewController).to(equal(rootViewController))
                        }
                    }

                    describe("when the call fails") {
                        beforeEach {
                            feedService.setTagsPromises.last?.resolve(.failure(.unknown))
                        }

                        it("dismisses itself") {
                            expect(navigationController.visibleViewController).to(equal(rootViewController))
                        }
                    }
                }
            }

            describe("editing both tags and url then saving") {
                let tags = ["d", "e", "f"]
                let url = URL(string: "https://example.com/new_feed")!

                beforeEach {
                    subject.feedDetailView.delegate?.feedDetailView(subject.feedDetailView, tagsDidChange: tags)
                    subject.feedDetailView.delegate?.feedDetailView(subject.feedDetailView, urlDidChange: url)

                    subject.navigationItem.rightBarButtonItem?.tap()
                }

                it("calls both the setTags and setURL methods on the Feed Service") {
                    expect(feedService.setTagsCalls).to(haveCount(1))
                    expect(feedService.setURLCalls).to(haveCount(1))
                }

                describe("when one of them finishes first") {
                    beforeEach {
                        feedService.setURLPromises.last?.resolve(.success(feed))
                    }

                    it("does not yet dismiss itself") {
                        expect(navigationController.visibleViewController).to(equal(subject))
                    }

                    describe("when the other finishes") {
                        beforeEach {
                            feedService.setTagsPromises.last?.resolve(.failure(.unknown))
                        }

                        it("dismisses itself") {
                            expect(navigationController.visibleViewController).to(equal(rootViewController))
                        }
                    }
                }
            }

            describe("feedDetailView(editTag:completion:)") {
                var newTag: String?
                var tagCompletionCallCount = 0

                context("with a nil tag") {
                    beforeEach {
                        newTag = nil
                        tagCompletionCallCount = 0
                        subject.feedDetailView.delegate?.feedDetailView(subject.feedDetailView, editTag: nil) {
                            newTag = $0
                            tagCompletionCallCount += 1
                        }
                    }

                    it("shows a tag editor controller to add the tag") {
                        expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
                        if let tagEditor = navigationController.topViewController as? TagEditorViewController {
                            expect(tagEditor.tag).to(beNil())
                        }
                    }

                    it("calls the callback when the tagEditor is done") {
                        expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
                        if let tagEditor = navigationController.topViewController as? TagEditorViewController {
                            tagEditor.onSave?("newTag")

                            expect(tagCompletionCallCount) == 1
                            expect(newTag) == "newTag"
                        }
                    }
                }

                context("with a tag") {
                    let existingTag = "hello"
                    beforeEach {
                        newTag = nil
                        tagCompletionCallCount = 0
                        subject.feedDetailView.delegate?.feedDetailView(subject.feedDetailView, editTag: existingTag) {
                            newTag = $0
                            tagCompletionCallCount += 1
                        }
                    }

                    it("shows a tag editor controller to add the tag") {
                        expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
                        if let tagEditor = navigationController.topViewController as? TagEditorViewController {
                            expect(tagEditor.tag) == "hello"
                        }
                    }

                    it("calls the callback when the tagEditor is done") {
                        expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
                        if let tagEditor = navigationController.topViewController as? TagEditorViewController {
                            tagEditor.onSave?("newTag")

                            expect(tagCompletionCallCount) == 1
                            expect(newTag) == "newTag"
                        }
                    }
                }
            }
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromOptionalNSAttributedStringKeyDictionary(_ input: [NSAttributedString.Key: Any]?) -> [String: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}
