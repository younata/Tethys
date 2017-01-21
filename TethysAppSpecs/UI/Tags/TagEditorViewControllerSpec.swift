import Quick
import Nimble
import Ra
import Tethys
import TethysKit

class TagEditorViewControllerSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil
        var dataRepository: FakeDatabaseUseCase! = nil
        var subject: TagEditorViewController! = nil
        var navigationController: UINavigationController! = nil
        var themeRepository: ThemeRepository! = nil
        let rootViewController = UIViewController()

        var callbackCallCount = 0
        var callbackTag: String?

        beforeEach {
            injector = Injector()
            dataRepository = FakeDatabaseUseCase()
            injector.bind(kind: DatabaseUseCase.self, toInstance: dataRepository)

            themeRepository = ThemeRepository(userDefaults: nil)
            injector.bind(kind: ThemeRepository.self, toInstance: themeRepository)

            subject = injector.create(kind: TagEditorViewController.self)!
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
            expect(dataRepository.allTagsPromises.count) == 1
        }

        describe("when the tags promise successfully resolves with tags") {
            beforeEach {
                dataRepository.allTagsPromises.last?.resolve(.success(["a"]))
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
                dataRepository.allTagsPromises.last?.resolve(.success([]))
            }

            it("disables the done button") {
                expect(subject.navigationItem.rightBarButtonItem?.isEnabled) == false
            }
        }

        describe("when tha tags promise errors out") {
            beforeEach {
                dataRepository.allTagsPromises.last?.resolve(.failure(.unknown))
            }

            it("disables the done button") {
                expect(subject.navigationItem.rightBarButtonItem?.isEnabled) == false
            }
        }
    }
}
