import Quick
import Nimble

import rNewsKit
import rNews

class ReadArticleUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultReadArticleUseCase!
        var feedRepository: FakeFeedRepository!
        var themeRepository: FakeThemeRepository!
        let bundle = NSBundle.mainBundle()

        beforeEach {
            feedRepository = FakeFeedRepository()
            themeRepository = FakeThemeRepository()
            subject = DefaultReadArticleUseCase(feedRepository: feedRepository, themeRepository: themeRepository, bundle: bundle)
        }

        describe("-readArticle:") {
            it("marks the article as read if it wasn't already") {
                let article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: NSDate(), identifier: "", content: "", read: false, estimatedReadingTime: 3, feed: nil, flags: [], enclosures: [])

                subject.readArticle(article)

                expect(feedRepository.lastArticleMarkedRead) == article
                expect(article.read) == true
            }

            it("doesn't mark the article as read if it already was") {
                let article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: NSDate(), identifier: "", content: "", read: true, estimatedReadingTime: 4, feed: nil, flags: [], enclosures: [])

                subject.readArticle(article)

                expect(feedRepository.lastArticleMarkedRead).to(beNil())
            }

            describe("the returned NSUserActivity") {
                var feed: Feed!
                var article: Article!

                var userActivity: NSUserActivity!
                beforeEach {
                    feed = Feed(title: "feedTitle", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    article = Article(title: "articleTitle", link: NSURL(string: "https://example.com"), summary: "articleSummary", author: "articleAuthor", published: NSDate(), updatedAt: NSDate(), identifier: "identifier", content: "", read: true, estimatedReadingTime: 4, feed: feed, flags: ["flag"], enclosures: [])

                    userActivity = subject.readArticle(article).userActivity
                }

                it("has a valid activity type") {
                    expect(userActivity.activityType) == "com.rachelbrindle.rssclient.article"
                }

                it("has it's title set to the feed and article's title") {
                    expect(userActivity.title) == "feedTitle: articleTitle"
                }

                it("has the webpageURL set to the article's link") {
                    expect(userActivity.webpageURL) == NSURL(string: "https://example.com")!
                }

                it("needs to be saved") {
                    expect(userActivity.needsSave) == true
                }

                it("is active") {
                    expect(userActivity.active) == true
                }

                describe("on iOS 9") {
                    guard #available(iOS 9, *) else { return }

                    it("has required user info keys of 'feed' and 'article'") {
                        expect(userActivity.requiredUserInfoKeys) == ["feed", "article"]
                    }

                    it("is not eligible for public indexing") {
                        expect(userActivity.eligibleForPublicIndexing) == false
                    }

                    it("is eligible for search") {
                        expect(userActivity.eligibleForSearch) == true
                    }

                    it("uses the article's title, summary, author, and flags as it's keywords") {
                        expect(userActivity.keywords) == ["articleTitle", "articleSummary", "articleAuthor", "flag"]
                    }
                }

                it("has a delegate") {
                    expect(userActivity.delegate).toNot(beNil())
                }

                it("the delegate sets it's userinfo upon saving") {
                    userActivity.delegate?.userActivityWillSave?(userActivity)

                    expect(userActivity.userInfo?["feed"] as? String) == "feedTitle"
                    expect(userActivity.userInfo?["article"] as? String) == "identifier"
                }
            }

            describe("the returned html string") {
                var html: String!

                beforeEach {
                    let article = Article(title: "articleTitle", link: nil, summary: "", author: "", published: NSDate(), updatedAt: NSDate(), identifier: "", content: "Example Content", read: true, estimatedReadingTime: 4, feed: nil, flags: [], enclosures: [])

                    html = subject.readArticle(article).html
                }

                it("is prefixed with the proper css") {
                    let cssURL = bundle.URLForResource(themeRepository.articleCSSFileName, withExtension: "css")!
                    let css = try! String(contentsOfURL: cssURL, encoding: NSUTF8StringEncoding)

                    let expectedPrefix = "<html><head>" +
                        "<style type=\"text/css\">\(css)</style>" +
                        "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                        "</head><body>"

                    expect(html.hasPrefix(expectedPrefix)) == true
                }

                it("is postfixed with prismJS") {
                    let prismURL = bundle.URLForResource("prism.js", withExtension: "html")!
                    let prismJS = try! String(contentsOfURL: prismURL, encoding: NSUTF8StringEncoding)
                    expect(html.hasSuffix(prismJS + "</body></html>")) == true
                }

                it("contains the article content") {
                    expect(html).to(contain("Example Content"))
                }

                it("contains the article title") {
                    expect(html).to(contain("<h2>articleTitle</h2>"))
                }

                it("is properly structured") {
                    let cssURL = bundle.URLForResource(themeRepository.articleCSSFileName, withExtension: "css")!
                    let css = try! String(contentsOfURL: cssURL, encoding: NSUTF8StringEncoding)

                    let expectedPrefix = "<html><head>" +
                        "<style type=\"text/css\">\(css)</style>" +
                        "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                    "</head><body>"

                    let prismURL = bundle.URLForResource("prism.js", withExtension: "html")!
                    let prismJS = try! String(contentsOfURL: prismURL, encoding: NSUTF8StringEncoding)

                    let expectedPostfix = prismJS + "</body></html>"

                    let expectedHTML = expectedPrefix + "<h2>articleTitle</h2>Example Content" + expectedPostfix

                    expect(html) == expectedHTML
                }
            }
        }

        describe("-toggleArticleRead:") {
            it("marks the article as read if it wasn't already") {
                let article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: NSDate(), identifier: "", content: "", read: false, estimatedReadingTime: 3, feed: nil, flags: [], enclosures: [])

                subject.toggleArticleRead(article)

                expect(feedRepository.lastArticleMarkedRead) == article
                expect(article.read) == true
            }

            it("marks the article as unread if it already was") {
                let article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: NSDate(), identifier: "", content: "", read: true, estimatedReadingTime: 4, feed: nil, flags: [], enclosures: [])

                subject.toggleArticleRead(article)

                expect(feedRepository.lastArticleMarkedRead) == article
                expect(article.read) == false
            }
        }
    }
}
