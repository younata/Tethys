import Quick
import Nimble
import rNews

class DocumentationUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultDocumentationUseCase!
        var themeRepository: ThemeRepository!

        let bundle = Bundle.main

        beforeEach {
            themeRepository = ThemeRepository(userDefaults: nil)

            subject = DefaultDocumentationUseCase(themeRepository: themeRepository, bundle: bundle)
        }

        describe("html(documentation: )") {
            it("returns the contents of the libraries.html file with css when given Documentation.libraries") {
                let cssURL = bundle.url(forResource: themeRepository.articleCSSFileName, withExtension: "css")!
                let css = try! String(contentsOf: cssURL)

                let expectedPrefix = "<html><head>" +
                    "<style type=\"text/css\">\(css)</style>" +
                    "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                "</head><body>"

                let expectedPostfix = "</body></html>"

                let librariesURL = bundle.url(forResource: "libraries", withExtension: "html")!
                let librariesContents = try! String(contentsOf: librariesURL)

                let expectedHTML = expectedPrefix + librariesContents + expectedPostfix

                expect(subject.html(documentation: .libraries)) == expectedHTML
            }
        }

        describe("title(documentation: )") {
            it("returns 'Libraries' when given Documentation.libraries") {
                expect(subject.title(documentation: .libraries)) == "Libraries"
            }
        }
    }
}
