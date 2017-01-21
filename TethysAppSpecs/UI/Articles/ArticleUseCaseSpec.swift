import Quick
import Nimble

@testable import TethysKit
import Tethys
import Result
import CBGPromise

class ArticleUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultArticleUseCase!
        var feedRepository: FakeDatabaseUseCase!
        var themeRepository: ThemeRepository!
        let bundle = Bundle.main

        beforeEach {
            feedRepository = FakeDatabaseUseCase()
            themeRepository = ThemeRepository(userDefaults: nil)
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
                let article1 = Article(title: "a", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [Author(name: "author", email: nil)], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])
                let article2 = Article(title: "b", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [Author(name: "foo", email: nil)], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])
                let article3 = Article(title: "c", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [Author(name: "author", email: nil)], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])
                let article4 = Article(title: "d", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [Author(name: "bar", email: nil)], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])

                let feed1 = Feed(title: "ab", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [article1, article2], image: nil)
                let feed2 = Feed(title: "cd", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [article3, article4], image: nil)
                article1.feed = feed1
                article2.feed = feed1
                article3.feed = feed2
                article4.feed = feed2

                beforeEach {
                    feedRepository.feedsPromises.last?.resolve(.success([feed1, feed2]))
                }

                it("calls the callback with a list of articles from those feeds filtered by article") {
                    expect(receivedArticles) == [article1, article3]
                }
            }

            context("when the feeds promise fails") {
                beforeEach {
                    feedRepository.feedsPromises.last?.resolve(.failure(.unknown))
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
                feed = Feed(title: "feedTitle", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                article = Article(title: "articleTitle", link: URL(string: "https://example.com")!, summary: "articleSummary", authors: [Author(name: "articleAuthor", email: nil)], published: Date(), updatedAt: Date(), identifier: "identifier", content: "", read: true, synced: false, estimatedReadingTime: 4, feed: feed, flags: ["flag"])

                userActivity = subject.userActivityForArticle(article)
            }

            it("has a valid activity type") {
                expect(userActivity.activityType) == "com.rachelbrindle.rssclient.article"
            }

            it("has it's title set to the feed and article's title") {
                expect(userActivity.title) == "feedTitle: articleTitle"
            }

            it("has the webpageURL set to the article's link") {
                expect(userActivity.webpageURL) == URL(string: "https://example.com")!
            }

            it("needs to be saved") {
                expect(userActivity.needsSave) == true
            }

            it("is active") {
                expect(userActivity.active) == true
            }

            it("has required user info keys of 'feed' and 'article'") {
                expect(userActivity.requiredUserInfoKeys) == ["feed", "article"]
            }

            it("is not eligible for public indexing") {
                expect(userActivity.isEligibleForPublicIndexing) == false
            }

            it("is eligible for search") {
                expect(userActivity.isEligibleForSearch) == true
            }

            it("uses the article's title, summary, author, and flags as it's keywords") {
                expect(userActivity.keywords) == ["articleTitle", "articleSummary", "articleAuthor", "flag"]
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
                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: false, synced: false, estimatedReadingTime: 3, feed: nil, flags: [])

                _ = subject.readArticle(article)

                expect(feedRepository.lastArticleMarkedRead) == article
                expect(article.read) == true
            }

            it("doesn't mark the article as read if it already was") {
                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true, synced: false, estimatedReadingTime: 4, feed: nil, flags: [])

                _ = subject.readArticle(article)

                expect(feedRepository.lastArticleMarkedRead).to(beNil())
            }

            it("tries to find articles related to this one") {
                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true, synced: false, estimatedReadingTime: 4, feed: nil, flags: [])

                _ = subject.readArticle(article)

                expect(feedRepository.relatedArticlesPromises.count).to(equal(1))
                expect(feedRepository.relatedArticles).to(equal([article]))
            }

            describe("the returned html string") {
                var html: String!

                beforeEach {
                    let article = Article(title: "articleTitle", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "Example Content", read: true, synced: false, estimatedReadingTime: 4, feed: nil, flags: [])

                    html = subject.readArticle(article)
                }

                it("is prefixed with the proper css") {
                    let cssURL = bundle.url(forResource: themeRepository.articleCSSFileName, withExtension: "css")!
                    let css = try! String(contentsOf: cssURL)

                    let expectedPrefix = "<html><head>" +
                        "<style type=\"text/css\">\(css)</style>" +
                        "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                        "</head><body>"

                    expect(html.hasPrefix(expectedPrefix)) == true
                }

                it("is postfixed with prismJS") {
                    let prismURL = bundle.url(forResource: "prism.js", withExtension: "html")!
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
                    let cssURL = bundle.url(forResource: themeRepository.articleCSSFileName, withExtension: "css")!
                    let css = try! String(contentsOf: cssURL)

                    let expectedPrefix = "<html><head>" +
                        "<style type=\"text/css\">\(css)</style>" +
                        "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                    "</head><body>"

                    let prismURL = bundle.url(forResource: "prism.js", withExtension: "html")!
                    let prismJS = try! String(contentsOf: prismURL)

                    let expectedPostfix = prismJS + "</body></html>"

                    let expectedHTML = expectedPrefix + "<h2>articleTitle</h2>Example Content" + expectedPostfix

                    expect(html) == expectedHTML
                }
            }
        }

        describe("-toggleArticleRead:") {
            it("marks the article as read if it wasn't already") {
                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: false, synced: false, estimatedReadingTime: 3, feed: nil, flags: [])

                subject.toggleArticleRead(article)

                expect(feedRepository.lastArticleMarkedRead) == article
                expect(article.read) == true
            }

            it("marks the article as unread if it already was") {
                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true, synced: false, estimatedReadingTime: 4, feed: nil, flags: [])

                subject.toggleArticleRead(article)

                expect(feedRepository.lastArticleMarkedRead) == article
                expect(article.read) == false
            }
        }

        describe("-relatedArticles(to:)") {
            var article: Article!
            var relatedArticles: [Article]?

            beforeEach {
                article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true, synced: false, estimatedReadingTime: 4, feed: nil, flags: [])
            }

            context("after a -readArticle() call has triggered asking for these relatedArticles") {
                beforeEach {
                    _ = subject.readArticle(article)
                }

                context("before the feedRepository has returned") {
                    beforeEach {
                        relatedArticles = subject.relatedArticles(to: article)
                    }

                    it("does not make another call to the data repository") {
                        expect(feedRepository.relatedArticlesPromises.count).to(equal(1))
                        expect(feedRepository.relatedArticles).to(equal([article]))
                    }

                    it("returns the article's related articles") {
                        expect(relatedArticles).to(beEmpty())
                    }

                    it("doesn't make another call to the data repository when asked again") {
                        _ = subject.relatedArticles(to: article)

                        expect(feedRepository.relatedArticlesPromises.count).to(equal(1))
                        expect(feedRepository.relatedArticles).to(equal([article]))
                    }

                    it("returns the related articles when asked again, after the data repository finishes") {
                        let otherArticle = Article(title: "", link: URL(string: "https://exapmle.com/2")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true, synced: false, estimatedReadingTime: 4, feed: nil, flags: [])

                        feedRepository.relatedArticlesPromises.last?.resolve(.success([otherArticle]))

                        relatedArticles = subject.relatedArticles(to: article)

                        expect(relatedArticles).to(equal([otherArticle]))
                    }
                }

                context("after the feed repository call finishes") {
                    let otherArticle = Article(title: "", link: URL(string: "https://exapmle.com/2")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true, synced: false, estimatedReadingTime: 4, feed: nil, flags: [])
                    beforeEach {
                        feedRepository.relatedArticlesPromises.last?.resolve(.success([otherArticle]))

                        relatedArticles = subject.relatedArticles(to: article)
                    }

                    it("does not make another call to the data repository") {
                        expect(feedRepository.relatedArticlesPromises.count).to(equal(1))
                        expect(feedRepository.relatedArticles).to(equal([article]))
                    }

                    it("returns the related articles") {
                        expect(relatedArticles).to(equal([otherArticle]))
                    }
                }
            }

            context("before a -readArticle() call") {
                context("and the article doesn't already have related articles") {
                    beforeEach {
                        relatedArticles = subject.relatedArticles(to: article)
                    }

                    it("makes a call to the data repository") {
                        expect(feedRepository.relatedArticlesPromises.count).to(equal(1))
                        expect(feedRepository.relatedArticles).to(equal([article]))
                    }

                    it("returns an empty array") {
                        expect(relatedArticles).to(beEmpty())
                    }

                    it("doesn't make another call to the data repository when asked again") {
                        _ = subject.relatedArticles(to: article)

                        expect(feedRepository.relatedArticlesPromises.count).to(equal(1))
                        expect(feedRepository.relatedArticles).to(equal([article]))
                    }

                    it("returns the related articles when asked again, after the data repository finishes") {
                        let otherArticle = Article(title: "", link: URL(string: "https://exapmle.com/2")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true, synced: false, estimatedReadingTime: 4, feed: nil, flags: [])

                        feedRepository.relatedArticlesPromises.last?.resolve(.success([otherArticle]))

                        relatedArticles = subject.relatedArticles(to: article)

                        expect(relatedArticles).to(equal([otherArticle]))
                    }
                }

                context("and the article does have saved related articles") {
                    var otherArticle: Article? = Article(title: "", link: URL(string: "https://exapmle.com/2")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true, synced: false, estimatedReadingTime: 4, feed: nil, flags: [])

                    beforeEach {
                        otherArticle = Article(title: "", link: URL(string: "https://exapmle.com/2")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true, synced: false, estimatedReadingTime: 4, feed: nil, flags: [])

                        article.addRelatedArticle(otherArticle!)

                        relatedArticles = subject.relatedArticles(to: article)
                    }

                    it("makes a call to the data repository") {
                        expect(feedRepository.relatedArticlesPromises.count).to(equal(1))
                        expect(feedRepository.relatedArticles).to(equal([article]))
                    }

                    it("returns the related articles") {
                        expect(relatedArticles).to(equal([otherArticle!]))
                    }

                    it("doesn't make another call to the data repository when asked again") {
                        _ = subject.relatedArticles(to: article)

                        expect(feedRepository.relatedArticlesPromises.count).to(equal(1))
                        expect(feedRepository.relatedArticles).to(equal([article]))
                    }

                    it("returns the related articles when asked again, after the data repository finishes") {
                        let thirdArticle = Article(title: "", link: URL(string: "https://exapmle.com/3")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true, synced: false, estimatedReadingTime: 4, feed: nil, flags: [])

                        feedRepository.relatedArticlesPromises.last?.resolve(.success([thirdArticle]))

                        relatedArticles = subject.relatedArticles(to: article)

                        expect(relatedArticles).to(equal([thirdArticle]))
                    }
                }
            }
        }
    }
}
