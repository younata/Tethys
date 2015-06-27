import Quick
import Nimble
import Ra
import rNews

class DataManagerSpec: QuickSpec {
    override func spec() {
        var subject : DataManager! = nil
        var injector : Ra.Injector! = nil

        var moc : NSManagedObjectContext! = nil

        var backgroundQueue : FakeOperationQueue! = nil
        var mainQueue : FakeOperationQueue! = nil

        var urlSession: FakeURLSession! = nil

        var feeds : [Feed] = []
        var feed1 : CoreDataFeed! = nil
        var feed2 : CoreDataFeed! = nil
        var feed3 : CoreDataFeed! = nil

        beforeEach {
            moc = managedObjectContext()

            backgroundQueue = FakeOperationQueue()
            mainQueue = FakeOperationQueue()
            for queue in [backgroundQueue, mainQueue] {
                queue.runSynchronously = true
            }
            injector = Ra.Injector()
            injector.bind(kBackgroundQueue, to: backgroundQueue)
            injector.bind(kMainQueue, to: mainQueue)

            urlSession = FakeURLSession()
            injector.bind(NSURLSession.self, to: urlSession)

            subject = injector.create(DataManager.self) as! DataManager
            subject.backgroundObjectContext = moc

            // seed with a few feeds/articles/enclosures

            feed1 = createFeed(moc)
            feed1.title = "a"
            feed1.url = "https://example.com/feed1.feed"
            feed1.tags = ["a", "b", "c"]
            let b = createArticle(moc)
            b.title = "b"
            let c = createArticle(moc)
            c.title = "c"
            feed1.addArticlesObject(b)
            feed1.addArticlesObject(c)
            b.feed = feed1
            c.feed = feed1
            feed2 = createFeed(moc) // query feed
            feed2.title = "d"
            feed2.tags = ["b", "d"]
            feed2.query = "return true"
            feed3 = createFeed(moc)
            feed3.title = "e"
            feed3.url = "https://example.com/feed3.feed"
            feed3.remainingWait = NSNumber(int: 1)
            feed3.tags = ["dad"]
            do {
                try moc.save()
            } catch _ {
            }

            feeds = [feed1, feed2, feed3].map { Feed(feed: $0) }
        }

        describe("operations on feeds") {
            describe("allTags") {
                it("should return a list of all tags used") {
                    expect(subject.allTags()).to(equal(["a", "b", "c", "d", "dad"]))
                }
            }

            describe("feeds") {
                it("should return a list of all feeds") {
                    expect(subject.feeds()).to(equal(feeds))
                }
            }

            describe("feedsMatchingTag") {
                it("should return all the feeds when no tag, or empty string is given as the tag") {
                    expect(subject.feedsMatchingTag(nil)).to(equal(feeds))
                    expect(subject.feedsMatchingTag("")).to(equal(feeds))
                }

                it("should return feeds that partially match a tag") {
                    let subFeeds = [feed1, feed3].map { Feed(feed: $0) }
                    expect(subject.feedsMatchingTag("a")).to(equal(subFeeds))
                }
            }

            describe("newFeed") {
                var callbackError: NSError? = nil
                var didCallCallback = false

                beforeEach {
                    didCallCallback = false
                }
                context("when there is not an existing feed with that url") {
                    var createdFeed: Feed! = nil
                    beforeEach {
                        createdFeed = subject.newFeed("https://example.com/rnews.feed") { error in
                            callbackError = error
                            didCallCallback = true
                        }
                    }

                    it("should insert a new feed into the core data store") {
                        expect(subject.feeds().count).to(equal(feeds.count + 1))
                    }

                    it("should not have yet called the callback") {
                        expect(didCallCallback).to(beFalsy())
                    }

                    it("should make a network request") {
                        expect(urlSession.lastURL).to(equal(NSURL(string: "https://example.com/rnews.feed")))
                    }

                    it("should return a bare feed") {
                        let expectedFeed = Feed(title: "", url: NSURL(string: "https://example.com/rnews.feed"), summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
                        expect(createdFeed).to(equal(expectedFeed))
                    }

                    context("when the network call succeeds") {
                        beforeEach {
                            let urlResponse = NSHTTPURLResponse(URL: NSURL(string: "https://example.com/rnews.feed")!, statusCode: 200, HTTPVersion: nil, headerFields: [:])
                            let bundle = NSBundle(forClass: OPMLParserSpec.self)
                            let data = NSData(contentsOfFile: bundle.pathForResource("feed2", ofType: "rss")!)
                            urlSession.lastCompletionHandler(data, urlResponse, nil)
                        }

                        it("should call the completion handler without an error") {
                            expect(didCallCallback).to(beTruthy())
                            expect(callbackError).to(beNil())
                        }

                        it("should fill out the feed now") {
                            let updatedFeed = DataUtility.feedsWithPredicate(NSPredicate(format: "url = %@", "https://example.com/rnews.feed"),
                                managedObjectContext: moc).first
                            expect(updatedFeed?.title).to(equal("objc.io"))
                        }
                    }

                    context("when the network call fails due to a network error") {
                        let error = NSError(domain: "", code: 1, userInfo: nil)
                        beforeEach {
                            urlSession.lastCompletionHandler(nil, nil, error)
                        }

                        it("should call the completion handler to let the caller know of an error updating the feed") {
                            expect(callbackError).to(equal(error))
                        }
                    }

                    context("when the network call fails due to a client/server error") {
                        beforeEach {
                            let urlResponse = NSHTTPURLResponse(URL: NSURL(string: "https://example.com/rnews.feed")!, statusCode: 400, HTTPVersion: nil, headerFields: [:])
                            urlSession.lastCompletionHandler(nil, urlResponse, nil)
                        }

                        it("should call the completion handler to let the caller know of an error updating the feed") {
                            expect(callbackError).toNot(beNil())
                            expect(callbackError?.code).to(equal(400))
                        }
                    }
                }

                context("when there is an existing feed with that url") {
                    beforeEach {
                        guard let url = feed1.url else {
                            return
                        }
                        subject.newFeed(url) { error in
                            callbackError = error
                        }
                    }

                    it("should not insert a new feed into the core data store") {
                        expect(subject.feeds()).to(equal(feeds))
                    }

                    it("should not call the callback") {
                        expect(didCallCallback).to(beFalsy())
                    }

                    it("should not make a network request") {
                        expect(urlSession.lastURL).to(beNil())
                    }
                }
            }

            describe("newQueryFeed") {
                context("when there is not an existing feed with that title") {
                    var createdFeed: Feed! = nil
                    beforeEach {
                        createdFeed = subject.newQueryFeed("query feed", code: "return true", summary: "a summary")
                    }

                    it("should return a filled-out query feed") {
                        expect(createdFeed.isQueryFeed).to(beTruthy())
                        expect(createdFeed.title).to(equal("query feed"))
                        expect(createdFeed.query).to(equal("return true"))
                        expect(createdFeed.summary).to(equal("a summary"))
                    }
                }

                context("when there is an existing feed with that title") {
                    beforeEach {
                        guard let title = feed2.title else {
                            return
                        }
                        subject.newQueryFeed(title, code: "return false")
                    }

                    it("should not insert a new feed into the core data store") {
                        expect(subject.feeds()).to(equal(feeds))
                    }
                }
            }

            describe("saveFeed") {
                var feed: Feed! = nil
                beforeEach {
                    feed = Feed(feed: feed1)
                    feed.summary = "a changed summary"
                    subject.saveFeed(feed)
                }

                it("should update the data store") {
                    let updatedFeed = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self = %@", feed1.objectID),
                        managedObjectContext: moc).first as? CoreDataFeed
                    expect(updatedFeed?.summary).to(equal(feed.summary))
                    if let updated = updatedFeed {
                        expect(Feed(feed: updated)).to(equal(feed))
                    }
                }
            }

            describe("deleteFeed") {
                var feed: Feed! = nil
                beforeEach {
                    feed = Feed(feed: feed1)
                    subject.deleteFeed(feed)
                }

                it("should remove the feed from the data store") {
                    expect(subject.feeds().contains(feed)).to(beFalsy())
                }
                
                it("should remove any articles associated with the feed") {
                    let articles = DataUtility.articlesWithPredicate(NSPredicate(value: true), managedObjectContext: moc)
                    let articleTitles = articles.map { $0.title }
                    expect(articleTitles).toNot(contain("b"))
                    expect(articleTitles).toNot(contain("c"))
                }
            }
            
            describe("markFeedAsRead") {
                beforeEach {
                    for article in feed1.articles {
                        expect(article.read).to(beFalsy())
                    }
                    subject.markFeedAsRead(Feed(feed: feed1))
                }
                it("should mark every article in the feed as read") {
                    let feed = DataUtility.feedsWithPredicate(NSPredicate(format: "self = %@", feed1.objectID), managedObjectContext: moc).first
                    for article in feed!.articles {
                        expect(article.read).to(beTruthy())
                    }
                    
                }
            }
        }
        
        describe("operations on individual articles") {
            var article: Article! = nil
            beforeEach {
                let feed = Feed(feed: feed1)
                article = feed.articles.first
            }

            describe("deleting an article") {
                beforeEach {
                    let coreDataArticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", article.articleID!),
                        managedObjectContext: moc).first
                    expect(coreDataArticle).toNot(beNil())
                    subject.deleteArticle(article)
                }
                it("should remove the article from the data store") {
                    let coreDataArticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", article.articleID!),
                        managedObjectContext: moc).first
                    expect(coreDataArticle).to(beNil())
                }
            }

            describe("marking an unread article as read") {
                beforeEach {
                    subject.markArticle(article, asRead: true)
                }

                it("should mark the article as read in the data store") {
                    let coreDataArticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", article.articleID!),
                        managedObjectContext: moc).first
                    expect(coreDataArticle).toNot(beNil())
                    if let cda = coreDataArticle as? CoreDataArticle {
                        expect(cda.read).to(beTruthy())
                    }
                }

                describe("and marking it as unread again") {
                    beforeEach {
                        subject.markArticle(article, asRead: false)
                    }

                    it("should mark the article as unread in the data store") {
                        let coreDataArticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", article.articleID!),
                            managedObjectContext: moc).first
                        expect(coreDataArticle).toNot(beNil())
                        if let cda = coreDataArticle as? CoreDataArticle {
                            expect(cda.read).to(beFalsy())
                        }
                    }
                }
            }

            describe("articlesMatchingQuery") {
                it("should return an array of articles matching the javascript query") {
                    // later
                }
            }
        }

        describe("updating feeds") {
            var didCallCallback = false
            var callbackError: NSError? = nil
            beforeEach {
                didCallCallback = false
                subject.updateFeeds {error in
                    didCallCallback = true
                    callbackError = error
                }
            }

            it("should make a network request for every feed in the data store w/ a url and a remaining wait of 0") {
                expect(urlSession.lastURL?.absoluteString).to(equal("https://example.com/feed1.feed"))
            }

            context("when the network request succeeds") {
                context("when the network call succeeds") {
                    beforeEach {
                        let urlResponse = NSHTTPURLResponse(URL: NSURL(string: "https://example.com/feed1.feed")!, statusCode: 200, HTTPVersion: nil, headerFields: [:])
                        let bundle = NSBundle(forClass: OPMLParserSpec.self)
                        let data = NSData(contentsOfFile: bundle.pathForResource("feed2", ofType: "rss")!)
                        urlSession.lastCompletionHandler(data, urlResponse, nil)
                    }

                    it("should call the completion handler without an error") {
                        expect(didCallCallback).to(beTruthy())
                        expect(callbackError).to(beNil())
                    }

                    it("should update the feed data now") {
                        let updatedFeed = DataUtility.feedsWithPredicate(NSPredicate(format: "url = %@", "https://example.com/feed1.feed"),
                            managedObjectContext: moc).first
                        expect(updatedFeed).toNot(beNil())
                        expect(updatedFeed?.title).to(equal("objc.io"))
                    }

                    context("when the feed contains an image") { // which it does
                        it("should try to download it") {
                            expect(urlSession.lastURL?.absoluteString).to(equal("http://example.org/icon.png"))
                        }

                        context("if that succeeds") {
                            var expectedImageData: NSData! = nil
                            beforeEach {
                                let bundle = NSBundle(forClass: self.classForCoder)
                                expectedImageData = NSData(contentsOfURL: bundle.URLForResource("test", withExtension: "jpg")!)
                                urlSession.lastCompletionHandler(expectedImageData, nil, nil)
                            }
                            it("should set the feed's image to that image") {
                                let updatedFeed = DataUtility.feedsWithPredicate(NSPredicate(format: "url = %@", "https://example.com/feed1.feed"),
                                    managedObjectContext: moc).first
                                expect(updatedFeed?.image).toNot(beNil())
                            }
                        }
                    }
                }
            }

            context("when the network call fails due to a network error") {
                let error = NSError(domain: "", code: 1, userInfo: nil)
                beforeEach {
                    urlSession.lastCompletionHandler(nil, nil, error)
                }

                it("should call the completion handler to let the caller know of an error updating the feed") {
                    expect(callbackError).to(equal(error))
                }
            }

            context("when the network call fails due to a client/server error") {
                beforeEach {
                    let urlResponse = NSHTTPURLResponse(URL: NSURL(string: "https://example.com/rnews.feed")!, statusCode: 400, HTTPVersion: nil, headerFields: [:])
                    urlSession.lastCompletionHandler(nil, urlResponse, nil)
                }

                it("should call the completion handler to let the caller know of an error updating the feed") {
                    expect(callbackError).toNot(beNil())
                    expect(callbackError?.code).to(equal(400))
                }
            }
        }
    }
}
