import Quick
import Nimble

@testable import TethysKit
import Tethys
import Result
import CBGPromise

class ArticleUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultArticleUseCase!
        var themeRepository: ThemeRepository!
        var articleService: FakeArticleService!

        beforeEach {
            themeRepository = ThemeRepository(userDefaults: nil)
            articleService = FakeArticleService()
            subject = DefaultArticleUseCase(
                articleService: articleService,
                themeRepository: themeRepository
            )
        }

        describe("-readArticle:") {
            it("marks the article as read") {
                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: false)

                _ = subject.readArticle(article)

                expect(articleService.markArticleAsReadCalls).to(haveCount(1))

                guard let call = articleService.markArticleAsReadCalls.last else {
                    fail("Didn't call ArticleService to mark article as read")
                    return
                }
                expect(call.article) == article
                expect(call.read) == true
            }

            describe("the returned html string") {
                var html: String!

                beforeEach {
                    let article = Article(title: "articleTitle", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "Example Content", read: true)

                    html = subject.readArticle(article)
                }

                it("is prefixed with the proper css") {
                    let cssURL = Bundle.main.url(forResource: themeRepository.articleCSSFileName, withExtension: "css")!
                    let css = try! String(contentsOf: cssURL)

                    let expectedPrefix = "<html><head>" +
                        "<style type=\"text/css\">\(css)</style>" +
                        "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                        "</head><body>"

                    expect(html.hasPrefix(expectedPrefix)) == true
                }

                it("is postfixed with prismJS") {
                    let prismURL = Bundle.main.url(forResource: "prism.js", withExtension: "html")!
                    let prismJS = try! String(contentsOf: prismURL)
                    expect(html.hasSuffix(prismJS + "</body></html>")) == true
                }

                it("contains the article content") {
                    expect(html).to(contain("Example Content"))
                }

                it("contains the article title") {
                    expect(html).to(contain("<h2>articleTitle</h2>"))
                }

                it("is properly structured") {
                    let cssURL = Bundle.main.url(forResource: themeRepository.articleCSSFileName, withExtension: "css")!
                    let css = try! String(contentsOf: cssURL)

                    let expectedPrefix = "<html><head>" +
                        "<style type=\"text/css\">\(css)</style>" +
                        "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                    "</head><body>"

                    let prismURL = Bundle.main.url(forResource: "prism.js", withExtension: "html")!
                    let prismJS = try! String(contentsOf: prismURL)

                    let expectedPostfix = prismJS + "</body></html>"

                    let expectedHTML = expectedPrefix + "<h2>articleTitle</h2>Example Content" + expectedPostfix

                    expect(html) == expectedHTML
                }
            }
        }

        describe("-toggleArticleRead:") {
            it("marks the article as read if it wasn't already") {
                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: false)

                subject.toggleArticleRead(article)

                expect(articleService.markArticleAsReadCalls).to(haveCount(1))

                guard let call = articleService.markArticleAsReadCalls.last else {
                    fail("Didn't call ArticleService to mark article as read")
                    return
                }
                expect(call.article) == article
                expect(call.read) == true
            }

            it("marks the article as unread if it already was") {
                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true)

                subject.toggleArticleRead(article)

                expect(articleService.markArticleAsReadCalls).to(haveCount(1))

                guard let call = articleService.markArticleAsReadCalls.last else {
                    fail("Didn't call ArticleService to mark article as unread")
                    return
                }
                expect(call.article) == article
                expect(call.read) == false
            }
        }
    }
}
