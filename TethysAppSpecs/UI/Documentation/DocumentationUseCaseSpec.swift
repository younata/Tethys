import Quick
import Nimble
import Tethys

class DocumentationUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultDocumentationUseCase!
        var themeRepository: ThemeRepository!

        beforeEach {
            themeRepository = ThemeRepository(userDefaults: nil)

            subject = DefaultDocumentationUseCase(themeRepository: themeRepository)
        }

        describe("html(documentation: )") {
            it("returns the contents of the libraries.html file with css when given Documentation.libraries") {
                let cssURL = Bundle.main.url(forResource: themeRepository.articleCSSFileName, withExtension: "css")!
                let css = try! String(contentsOf: cssURL)

                let expectedPrefix = "<html><head>" +
                    "<style type=\"text/css\">\(css)</style>" +
                    "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                "</head><body>"

                let expectedPostfix = "</body></html>"

                let librariesURL = Bundle.main.url(forResource: "libraries", withExtension: "html")!
                let librariesContents = try! String(contentsOf: librariesURL)

                let expectedHTML = expectedPrefix + librariesContents + expectedPostfix

                expect(subject.html(documentation: .libraries)) == expectedHTML
            }

            it("returns the contents of the icons.html file with css when given Documentation.icons") {
                let cssURL = Bundle.main.url(forResource: themeRepository.articleCSSFileName, withExtension: "css")!
                let css = try! String(contentsOf: cssURL)

                let expectedPrefix = "<html><head>" +
                    "<style type=\"text/css\">\(css)</style>" +
                    "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                "</head><body>"

                let expectedPostfix = "</body></html>"

                let librariesURL = Bundle.main.url(forResource: "icons", withExtension: "html")!
                let librariesContents = try! String(contentsOf: librariesURL)

                let expectedHTML = expectedPrefix + librariesContents + expectedPostfix

                expect(subject.html(documentation: .icons)) == expectedHTML
            }
        }

        describe("title(documentation: )") {
            it("returns 'Libraries' when given Documentation.libraries") {
                expect(subject.title(documentation: .libraries)) == "Libraries"
            }

            it("returns 'Icons' when given Documentation.icons") {
                expect(subject.title(documentation: .icons)) == "Icons"
            }
        }
    }
}
