import Quick
import Nimble

import rNews

class DocumentationUseCaseSpec: QuickSpec {
    override func spec() {
        describe("Document") {
            it("has the right title") {
                expect(Document.QueryFeed.title) == "Query Feeds"
            }
        }

        describe("DocumentationUseCase") {
            let bundle = NSBundle.mainBundle()
            var themeRepository: FakeThemeRepository!
            var subject: DefaultDocumentationUseCase!

            func loadDataFromBundle(name: String, fileExtension: String?) -> String {
                return try! String(contentsOfURL: bundle.URLForResource(name, withExtension: fileExtension)!, encoding: NSUTF8StringEncoding)
            }

            it("returns the correct HTML displaying the document") {
                themeRepository = FakeThemeRepository()
                subject = DefaultDocumentationUseCase(bundle: bundle, themeRepository: themeRepository)

                let document = Document.QueryFeed

                let documentContents = loadDataFromBundle(document.rawValue, fileExtension: "html")

                expect(subject.htmlForDocument(document)).to(contain(documentContents))

                let cssContents = loadDataFromBundle(themeRepository.articleCSSFileName, fileExtension: "css")
                expect(subject.htmlForDocument(document)).to(contain(cssContents))

                let prismJS = loadDataFromBundle("prism.js", fileExtension: "html")
                expect(subject.htmlForDocument(document)).to(contain(prismJS))

                let expectedContent =  "<html><head><style type=\"text/css\">\(cssContents)</style></head><body>" +
                    documentContents + prismJS + "</body></html>"
                expect(subject.htmlForDocument(document)) == expectedContent
            }
        }
    }
}
