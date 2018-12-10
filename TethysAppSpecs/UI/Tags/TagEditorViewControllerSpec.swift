import Quick
import Nimble
import Tethys
import TethysKit

class TagEditorViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: TagEditorViewController!
        var feedService: FakeFeedService!
        var themeRepository: ThemeRepository!

        var navigationController: UINavigationController!
        let rootViewController = UIViewController()


        var callbackCallCount = 0
        var callbackTag: String?

        beforeEach {
            feedService = FakeFeedService()
            themeRepository = ThemeRepository(userDefaults: nil)

            subject = TagEditorViewController(feedService: feedService, themeRepository: themeRepository)

            navigationController = UINavigationController(rootViewController: rootViewController)
            navigationController.pushViewController(subject, animated: false)

            callbackCallCount = 0
            callbackTag = nil

            subject.onSave = { tag in
                callbackCallCount += 1
                callbackTag = tag
            }

            expect(subject.view).toNot(beNil())
            expect(navigationController.topViewController) == subject
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("should change background color") {
                expect(subject.view.backgroundColor) == themeRepository.backgroundColor
            }

            it("should change the navigation bar style") {
                expect(subject.navigationController?.navigationBar.barTintColor) == themeRepository.backgroundColor
            }

            it("should change the tagPicker's textColors") {
                expect(subject.tagPicker.textField.textColor) == themeRepository.textColor
            }
        }

        it("sets the title to 'Tags'") {
            expect(subject.navigationItem.title) == "Tags"
        }

        it("has a done button") {
            expect(subject.navigationItem.rightBarButtonItem?.title) == "Done"
        }

        it("asks for the list of all tags") {
            expect(feedService.tagsPromises).to(haveCount(1))
        }

        describe("when the tags promise successfully resolves with tags") {
            beforeEach {
                feedService.tagsPromises.last?.resolve(.success(AnyCollection(["a"])))
            }

            context("when there is data to save") {
                beforeEach {
                    _ = subject.tagPicker.textField(subject.tagPicker.textField, shouldChangeCharactersIn: NSMakeRange(0, 0), replacementString: "a")
                    subject.navigationItem.rightBarButtonItem?.tap()
                }

                it("calls the callback with the tag") {
                    expect(callbackCallCount) == 1
                    expect(callbackTag) == "a"
                }

                it("should pop the navigation controller") {
                    expect(navigationController.topViewController) == rootViewController
                }
            }

            context("when there is not data to add a new tag") {
                it("is not even be enabled") {
                    expect(subject.navigationItem.rightBarButtonItem?.isEnabled) == false
                }
            }
        }

        describe("when the tags promise successfully resolves without tags") {
            beforeEach {
                feedService.tagsPromises.last?.resolve(.success(AnyCollection([])))
            }

            it("disables the done button") {
                expect(subject.navigationItem.rightBarButtonItem?.isEnabled) == false
            }
        }

        describe("when tha tags promise errors out") {
            beforeEach {
                feedService.tagsPromises.last?.resolve(.failure(.unknown))
            }

            it("disables the save button") {
                expect(subject.navigationItem.rightBarButtonItem?.isEnabled) == false
            }
        }
    }
}
