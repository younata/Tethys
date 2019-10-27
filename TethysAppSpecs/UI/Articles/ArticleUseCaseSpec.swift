import Quick
import Nimble

@testable import TethysKit
import Tethys
import Result
import CBGPromise

class ArticleUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultArticleUseCase!
        var articleService: FakeArticleService!

        beforeEach {
            articleService = FakeArticleService()
            subject = DefaultArticleUseCase(
                articleService: articleService
            )
        }

        describe("-readArticle:") {
            it("marks the article as read") {
                let article = articleFactory(link: URL(string: "https://exapmle.com/1")!, read: false)

                _ = subject.readArticle(article)

                expect(articleService.markArticleAsReadCalls).to(haveCount(1))

                guard let call = articleService.markArticleAsReadCalls.last else {
                    fail("Didn't call ArticleService to mark article as read")
                    return
                }
                expect(call.article).to(equal(article))
                expect(call.read).to(beTrue())
            }

            describe("the returned html string") {
                var html: String!

                beforeEach {
                    let article = articleFactory(title: "articleTitle", link: URL(string: "https://exapmle.com/1")!,
                                          content: "Example Content", read: true)

                    html = subject.readArticle(article)
                }

                it("is prefixed with the proper css") {
                    let cssURL = Bundle.main.url(forResource: Theme.articleCSSFileName, withExtension: "css")!
                    let css = try! String(contentsOf: cssURL)

                    let expectedPrefix = "<html><head>" +
                        "<style type=\"text/css\">\(css)</style>" +
                        "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                        "</head><body>"

                    expect(html.hasPrefix(expectedPrefix)).to(beTrue())
                }

                it("is postfixed with prismJS") {
                    let prismURL = Bundle.main.url(forResource: "prism.js", withExtension: "html")!
                    let prismJS = try! String(contentsOf: prismURL)
                    expect(html.hasSuffix(prismJS + "</body></html>")).to(beTrue())
                }

                it("contains the article content") {
                    expect(html).to(contain("Example Content"))
                }

                it("contains the article title") {
                    expect(html).to(contain("<h2>articleTitle</h2>"))
                }

                it("is properly structured") {
                    let cssURL = Bundle.main.url(forResource: Theme.articleCSSFileName, withExtension: "css")!
                    let css = try! String(contentsOf: cssURL)

                    let expectedPrefix = "<html><head>" +
                        "<style type=\"text/css\">\(css)</style>" +
                        "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                    "</head><body>"

                    let prismURL = Bundle.main.url(forResource: "prism.js", withExtension: "html")!
                    let prismJS = try! String(contentsOf: prismURL)

                    let expectedPostfix = prismJS + "</body></html>"

                    let expectedHTML = expectedPrefix + "<h2>articleTitle</h2>Example Content" + expectedPostfix

                    expect(html).to(equal(expectedHTML))
                }
            }
        }

        describe("-toggleArticleRead:") {
            it("marks the article as read if it wasn't already") {
                let article = articleFactory(link: URL(string: "https://exapmle.com/1")!, read: false)

                subject.toggleArticleRead(article)

                expect(articleService.markArticleAsReadCalls).to(haveCount(1))

                guard let call = articleService.markArticleAsReadCalls.last else {
                    fail("Didn't call ArticleService to mark article as read")
                    return
                }
                expect(call.article).to(equal(article))
                expect(call.read).to(beTrue())
            }

            it("marks the article as unread if it already was") {
                let article = articleFactory(link: URL(string: "https://exapmle.com/1")!, read: true)

                subject.toggleArticleRead(article)

                expect(articleService.markArticleAsReadCalls).to(haveCount(1))

                guard let call = articleService.markArticleAsReadCalls.last else {
                    fail("Didn't call ArticleService to mark article as unread")
                    return
                }
                expect(call.article).to(equal(article))
                expect(call.read).to(beFalse())
            }
        }
    }
}
