import Quick
import Nimble
import rNews
import Ra

class GenerateBookViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: GenerateBookViewController!
        var injector: Injector!
        var themeRepository: ThemeRepository!
        var navController: UINavigationController!
        var presentingController: UIViewController!

        beforeEach {
            injector = Injector()

            themeRepository = ThemeRepository(userDefaults: nil)
            injector.bind(kind: ThemeRepository.self, toInstance: themeRepository)

            subject = injector.create(kind: GenerateBookViewController.self)!

            presentingController = UIViewController()
            navController = UINavigationController(rootViewController: subject)
            presentingController.present(navController, animated: false, completion: nil)

            subject.view.layoutIfNeeded()
        }

        describe("listening to theme repository updates") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("should update the navigation bar") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
                expect(subject.navigationController?.navigationBar.titleTextAttributes as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
            }

            it("updates the background color") {
                expect(subject.view.backgroundColor) == themeRepository.backgroundColor
            }

            it("changes the text color of the title field") {
                expect(subject.titleField.textColor) == themeRepository.textColor
            }

            it("changes the text color of the author field") {
                expect(subject.authorField.textColor) == themeRepository.textColor
            }

            it("sets the title text attributes for the segmented control") {
                expect(subject.formatSelector.titleTextAttributes(for: UIControlState.normal) as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
                expect(subject.formatSelector.titleTextAttributes(for: UIControlState.selected) as? [String: UIColor]) == [
                    NSForegroundColorAttributeName: themeRepository.backgroundColor
                ]
            }
        }

        it("sets a title") {
            expect(subject.title) == "Create eBook"
        }

        describe("the leftBarButtonItem") {
            var item: UIBarButtonItem?

            beforeEach {
                item = subject.navigationItem.leftBarButtonItem
            }

            it("is titled 'Dismiss'") {
                expect(item?.title) == "Dismiss"
            }

            it("dismisses the view controller when tapped") {
                item?.tap()

                expect(presentingController.presentedViewController).to(beNil())
            }
        }

        describe("the format selector") {
            it("has two formats to choose between - ePub and Kindle") {
                expect(subject.formatSelector.numberOfSegments) == 2
                expect(subject.formatSelector.titleForSegment(at: 0)) == "ePub"
                expect(subject.formatSelector.titleForSegment(at: 1)) == "Kindle"
            }

            it("initially selects ePub") {
                expect(subject.formatSelector.selectedSegmentIndex) == 0
            }

            it("has an accessibility hint") {
                expect(subject.formatSelector.accessibilityHint) == "Book Format (ePub or Kindle)"
            }
        }

        describe("the title field") {
            it("has a placeholder set to 'Title'") {
                expect(subject.titleField.placeholder) == "Title"
            }

            it("has an accessibility hint") {
                expect(subject.titleField.accessibilityHint) == "Book Title"
            }
        }

        describe("the author field") {
            it("has a placeholder set to 'Author'") {
                expect(subject.authorField.placeholder) == "Author"
            }

            it("hsa an accessibility hint") {
                expect(subject.authorField.accessibilityHint) == "Book Author"
            }
        }

        describe("the generate button") {
            let enterTitle = {
                subject.titleField.text = "title"
                _ = subject.titleField.delegate?.textField?(subject.titleField,
                                                            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
                                                            replacementString: "")
            }

            let enterAuthor = {
                subject.authorField.text = "title"
                _ = subject.authorField.delegate?.textField?(subject.authorField,
                                                             shouldChangeCharactersIn: NSRange(location: 0, length: 0),
                                                             replacementString: "")
            }

            it("is initially disabled") {
                expect(subject.generateButton.isEnabled) == false
            }

            it("is titled 'Create'") {
                expect(subject.generateButton.title(for: .normal)) == "Create"
            }

            it("is still disabled when the title is set and nothing else") {
                enterTitle()

                expect(subject.generateButton.isEnabled) == false
            }

            it("is still disabled when the author is set and nothing else") {
                enterAuthor()

                expect(subject.generateButton.isEnabled) == false
            }

            it("is still disabled when the title and author are set, but not articles are selected") {
                enterTitle()
                enterAuthor()

                expect(subject.generateButton.isEnabled) == false
            }
        }
    }
}
