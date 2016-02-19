import Quick
import Nimble
import rNews
import Ra

class DocumentationViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: DocumentationViewController!
        var themeRepository: FakeThemeRepository!
        var documentationUseCase: FakeDocumentationUseCase!
        var navigationController: UINavigationController!

        beforeEach {
            let injector = Injector()

            documentationUseCase = FakeDocumentationUseCase()
            injector.bind(DocumentationUseCase.self, toInstance: documentationUseCase)

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, toInstance: themeRepository)

            subject = injector.create(DocumentationViewController)!
            navigationController = UINavigationController(rootViewController: subject)
            subject.view.layoutIfNeeded()
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should update the navigation bar background") {
                expect(navigationController.navigationBar.barStyle).to(equal(themeRepository.barStyle))
            }

            it("should update the view background") {
                expect(subject.view.backgroundColor).to(equal(themeRepository.backgroundColor))
            }
        }

        describe("configuring with a document") {
            describe("with a Query Feed") {
                beforeEach {
                    documentationUseCase.htmlForDocumentReturns("foo")
                    subject.configure(.QueryFeed)
                }

                it("changes the title") {
                    expect(subject.title).to(equal("Query Feeds"))
                }

                it("asks the documentation use case for the Document's content") {
                    expect(documentationUseCase.htmlForDocumentCallCount) == 1
                    expect(documentationUseCase.htmlForDocumentArgsForCall(0)) == Document.QueryFeed
                }
            }
        }
    }
}
