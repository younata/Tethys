import Quick
import Nimble

@testable import rNewsKit
import rNews

class ArticleUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultArticleUseCase!
        var feedRepository: FakeDatabaseUseCase!
        var themeRepository: FakeThemeRepository!
        let bundle = NSBundle.mainBundle()

        beforeEach {
            feedRepository = FakeDatabaseUseCase()
            themeRepository = FakeThemeRepository()
            subject = DefaultArticleUseCase(feedRepository: feedRepository, themeRepository: themeRepository, bundle: bundle)
        }

        describe("-articlesByAuthor:") {
            var receivedArticles: [Article]? = nil

            beforeEach {
                subject.articlesByAuthor(Author(name: "author", email: nil)) {
                    receivedArticles = Array($0)
                }
            }

            it("asks the feed repository for all feeds") {
                expect(feedRepository.feedsPromises.count) == 1
            }

            context("when the feeds promise resolves successfully") {
                let article1 = Article(title: "a", link: nil, summary: "", authors: [Author(name: "author", email: nil)], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
                let article2 = Article(title: "b", link: nil, summary: "", authors: [Author(name: "foo", email: nil)], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
                let article3 = Article(title: "c", link: nil, summary: "", authors: [Author(name: "author", email: nil)], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
                let article4 = Article(title: "d", link: nil, summary: "", authors: [Author(name: "bar", email: nil)], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])

                let feed1 = Feed(title: "ab", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [article1, article2], image: nil)
                let feed2 = Feed(title: "cd", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [article3, article4], image: nil)
                article1.feed = feed1
                article2.feed = feed1
                article3.feed = feed2
                article4.feed = feed2

                beforeEach {
                    feedRepository.feedsPromises.last?.resolve(.Success([feed1, feed2]))
                }

                it("calls the callback with a list of articles from those feeds filtered by article") {
                    expect(receivedArticles) == [article1, article3]
                }
            }

            context("when the feeds promise fails") {
                beforeEach {
                    feedRepository.feedsPromises.last?.resolve(.Failure(.Unknown))
                }

                it("calls the callback with nothing") {
                    expect(receivedArticles) == []
                }
            }
        }

        describe("-userActivityForArticle:") {
            var feed: Feed!
            var article: Article!

            var userActivity: NSUserActivity!

            beforeEach {
                feed = Feed(title: "feedTitle", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                article = Article(title: "articleTitle", link: NSURL(string: "https://example.com"), summary: "articleSummary", authors: [Author(name: "articleAuthor", email: nil)], published: NSDate(), updatedAt: NSDate(), identifier: "identifier", content: "", read: true, estimatedReadingTime: 4, feed: feed, flags: ["flag"], enclosures: [])

                userActivity = subject.userActivityForArticle(article)
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

        describe("-readArticle:") {
            it("marks the article as read if it wasn't already") {
                let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: NSDate(), identifier: "", content: "", read: false, estimatedReadingTime: 3, feed: nil, flags: [], enclosures: [])

                subject.readArticle(article)

                expect(feedRepository.lastArticleMarkedRead) == article
                expect(article.read) == true
            }

            it("doesn't mark the article as read if it already was") {
                let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: NSDate(), identifier: "", content: "", read: true, estimatedReadingTime: 4, feed: nil, flags: [], enclosures: [])

                subject.readArticle(article)

                expect(feedRepository.lastArticleMarkedRead).to(beNil())
            }

            describe("the returned html string") {
                var html: String!

                beforeEach {
                    let article = Article(title: "articleTitle", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: NSDate(), identifier: "", content: "Example Content", read: true, estimatedReadingTime: 4, feed: nil, flags: [], enclosures: [])

                    html = subject.readArticle(article)
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
                let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: NSDate(), identifier: "", content: "", read: false, estimatedReadingTime: 3, feed: nil, flags: [], enclosures: [])

                subject.toggleArticleRead(article)

                expect(feedRepository.lastArticleMarkedRead) == article
                expect(article.read) == true
            }

            it("marks the article as unread if it already was") {
                let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: NSDate(), identifier: "", content: "", read: true, estimatedReadingTime: 4, feed: nil, flags: [], enclosures: [])

                subject.toggleArticleRead(article)

                expect(feedRepository.lastArticleMarkedRead) == article
                expect(article.read) == false
            }
        }
    }
}
