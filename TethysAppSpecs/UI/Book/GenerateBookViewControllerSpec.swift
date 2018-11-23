import Quick
import Nimble
import Tethys
import TethysKit
import CBGPromise
import Result
import Sponde

class GenerateBookViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: GenerateBookViewController!
        var themeRepository: ThemeRepository!
        var generateBookUseCase: FakeGenerateBookUseCase!
        var navController: UINavigationController!
        var presentingController: UIViewController!

        beforeEach {
            themeRepository = ThemeRepository(userDefaults: nil)
            generateBookUseCase = FakeGenerateBookUseCase()

            subject = GenerateBookViewController(
                themeRepository: themeRepository,
                generateBookUseCase: generateBookUseCase,
                chapterOrganizer: ChapterOrganizerController(
                    themeRepository: themeRepository,
                    settingsRepository: SettingsRepository(userDefaults: nil),
                    articleCellController: FakeArticleCellController(),
                    articleListController: { fatalError() }
                )
            )

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

        describe("setting the articles") {
            let articles = AnyCollection([
                Article(title: "Article 1", link: URL(string: "https://example.com/1")!, summary: "", authors: [],
                        published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                        synced: false, feed: nil, flags: []),
                Article(title: "Article 2", link: URL(string: "https://example.com/2")!, summary: "", authors: [],
                        published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                        synced: false, feed: nil, flags: []),
                Article(title: "Article 3", link: URL(string: "https://example.com/3")!, summary: "", authors: [],
                        published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                        synced: false, feed: nil, flags: []),
            ])

            it("also sets the articles on the chapterorganizer") {
                subject.articles = articles
                expect(Array(subject.chapterOrganizer.articles)) == Array(articles)
            }
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
            let chapters: [Article] = [
                Article(title: "Article 1", link: URL(string: "https://example.com/1")!, summary: "", authors: [],
                        published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                        synced: false, feed: nil, flags: []),
                Article(title: "Article 2", link: URL(string: "https://example.com/2")!, summary: "", authors: [],
                        published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                        synced: false, feed: nil, flags: []),
                Article(title: "Article 3", link: URL(string: "https://example.com/3")!, summary: "", authors: [],
                        published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                        synced: false, feed: nil, flags: []),
            ]

            let enterTitle = {
                subject.titleField.text = "title"
                let shouldChange = subject.titleField.delegate?.textField?(subject.titleField,
                                                                           shouldChangeCharactersIn: NSRange(location: 0, length: 0),
                                                                           replacementString: "")
                expect(shouldChange) == true
            }

            let enterAuthor = {
                subject.authorField.text = "author"
                let shouldChange = subject.authorField.delegate?.textField?(subject.authorField,
                                                                            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
                                                                            replacementString: "")
                expect(shouldChange) == true
            }

            let enterChapters = {
                subject.chapterOrganizer.chapters = chapters
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

            it("is still disabled when articles are set, but not title or author") {
                enterChapters()

                expect(subject.generateButton.isEnabled) == false
            }

            it("is still disabled when title and chapters are set, but not author") {
                enterTitle()
                enterChapters()

                expect(subject.generateButton.isEnabled) == false
            }

            it("is still disabled when author and chapters are set, but not title") {
                enterAuthor()
                enterChapters()

                expect(subject.generateButton.isEnabled) == false
            }

            it("only becomes enabled when the title, author, and chapters are set") {
                enterTitle()
                enterAuthor()
                enterChapters()

                expect(subject.generateButton.isEnabled) == true
            }

            describe("tapping the generateButton") {
                var generateBookPromise: Promise<Result<URL, TethysError>>!

                beforeEach {
                    generateBookPromise = Promise<Result<URL, TethysError>>()
                    generateBookUseCase.generateBookReturns(generateBookPromise.future)
                }

                sharedExamples("generating an ebook") { (sharedContext: @escaping SharedExampleContext) in
                    var format: Book.Format!

                    beforeEach {
                        format = sharedContext()["format"] as! Book.Format
                    }

                    it("shows an indicator that we're doing things") {
                        let indicator = subject.view.subviews.filter {
                            return $0.isKind(of: ActivityIndicator.classForCoder())
                            }.first as? ActivityIndicator
                        expect(indicator?.message) == "Generating eBook"
                    }

                    it("makes a request to the generate book use case") {
                        expect(generateBookUseCase.generateBookCallCount) == 1

                        guard generateBookUseCase.generateBookCallCount == 1 else { return }

                        let args = generateBookUseCase.generateBookArgsForCall(0)
                        expect(args.0) == "title"
                        expect(args.1) == "author"
                        expect(args.2) == chapters
                        expect(args.3) == format
                    }

                    describe("when the generate book call succeeds") {
                        let url = URL(fileURLWithPath: "/test/path")

                        beforeEach {
                            generateBookPromise.resolve(.success(url))
                        }

                        it("removes the indicator") {
                            let indicator = subject.view.subviews.filter {
                                return $0.isKind(of: ActivityIndicator.classForCoder())
                                }.first
                            expect(indicator).to(beNil())
                        }

                        it("presents a share sheet") {
                            expect(subject.presentedViewController).to(beAnInstanceOf(UIActivityViewController.self))
                            if let activityVC = subject.presentedViewController as? UIActivityViewController {
                                expect(activityVC.activityItems as? [URL]) == [url]
                            }
                        }
                    }

                    describe("when the generate book call fails") {
                        beforeEach {
                            generateBookPromise.resolve(.failure(.book(.unknown)))
                        }

                        it("removes the indicator") {
                            let indicator = subject.view.subviews.filter {
                                return $0.isKind(of: ActivityIndicator.classForCoder())
                                }.first
                            expect(indicator).to(beNil())
                        }

                        it("shows an alert box") {
                            expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                            if let alert = subject.presentedViewController as? UIAlertController {
                                expect(alert.title) == "Unable to Generate eBook"
                                expect(alert.message) == "Unknown Error"
                                expect(alert.actions.count) == 1
                                if let action = alert.actions.first {
                                    expect(action.title) == "Ok"
                                    action.handler?(action)
                                    expect(subject.presentedViewController).to(beNil())
                                }
                            }
                        }
                    }
                }

                context("with epub selected") {
                    beforeEach {
                        enterTitle()
                        enterAuthor()
                        enterChapters()

                        subject.formatSelector.selectedSegmentIndex = 0

                        subject.generateButton.sendActions(for: .touchUpInside)
                    }

                    itBehavesLike("generating an ebook") { () -> [String : Any] in
                        return ["format": Book.Format.epub]
                    }
                }

                context("with kindle selected") {
                    beforeEach {
                        enterTitle()
                        enterAuthor()
                        enterChapters()

                        subject.formatSelector.selectedSegmentIndex = 1

                        subject.generateButton.sendActions(for: .touchUpInside)
                    }

                    itBehavesLike("generating an ebook") { () -> [String : Any] in
                        return ["format": Book.Format.mobi]
                    }
                }
            }
        }
    }
}
