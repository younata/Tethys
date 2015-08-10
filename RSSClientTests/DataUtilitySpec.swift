import Quick
import Nimble
import Foundation
import Muon
import CoreData
@testable import rNewsKit

class DataUtilitySpec: QuickSpec {
    override func spec() {
        var ctx: NSManagedObjectContext! = nil
        var feed: CoreDataFeed! = nil

        var info: Muon.Feed! = nil

        beforeEach {
            ctx = managedObjectContext()
            feed = createFeed(ctx)
        }

        describe("updateFeed:info:") {
            beforeEach {
                info = Muon.Feed(title: "example feed", link: NSURL(string: "http://example.com")!, description: "example", articles: [])
            }
            it("should update the feed accordingly") {
                DataUtility.updateFeed(feed, info: info)

                expect(feed.title).to(equal("example feed"))
                expect(feed.summary).to(equal("example"))
            }
        }

        describe("updateFeedImage:info:urlSession:") {
            let imageURL = NSURL(string: "https://raw.githubusercontent.com/younata/RSSClient/master/RSSClient/Images.xcassets/AppIcon.appiconset/Icon@2x.png")!
            beforeEach {
                info = Muon.Feed(title: "example", link: NSURL(string: "http://example.com")!, description: "example", articles: [], imageURL: imageURL)
            }

            context("when the feed doesn't have an existing image") {
                it("should download the image pointed at by info.imageURL and set it as the feed image") {
                    let urlSession = FakeURLSession()
                    DataUtility.updateFeedImage(feed, info: info, urlSession: urlSession)
                    let image = NSBundle(forClass: self.classForCoder).imageForResource("AppIcon")!
                    #if os(OSX)
                        let data = image.TIFFRepresentation
                    #elseif os(iOS)
                        let data = UIImagePNGRepresentation(image)
                    #endif
                    urlSession.lastCompletionHandler(data, nil, nil)

                    expect(feed.image).toNot(beNil())
                }
            }
            context("when the feed has an existing image") {
                beforeEach {
                    feed.image = NSBundle(forClass: self.classForCoder).imageForResource("AppIcon")!
                    do {
                        try feed.managedObjectContext?.save()
                    } catch _ {
                    }
                }

                it("should not update the feed image") {
                    let urlSession = FakeURLSession()
                    DataUtility.updateFeedImage(feed, info: info, urlSession: urlSession)
                    expect(urlSession.lastURL).to(beNil())

                    expect(feed.hasChanges).to(beFalsy())
                }
            }
        }

        describe("updateArticle:item:") {
            var article: CoreDataArticle! = nil
            var item : Muon.Article! = nil
            beforeEach {
                article = createArticle(ctx)
                do {
                    try ctx.save()
                } catch _ {
                }

                let author = Muon.Author(name: "me", email: nil, uri: nil)

                item = Muon.Article(title: "example", link: NSURL(string: "http://example.com"), description: "summary",
                    content: "content", guid: "0xDEADBEEF", published: NSDate(timeIntervalSinceReferenceDate: 0),
                    updated: NSDate(timeIntervalSinceReferenceDate: 10), authors: [author], enclosures: [])
            }

            it("should update an article with the given feed item") {
                DataUtility.updateArticle(article, item: item)

                expect(article.title).to(equal("example"))
                expect(article.link).to(equal("http://example.com"))
                expect(article.published).to(equal(NSDate(timeIntervalSinceReferenceDate: 0)))
                expect(article.updatedAt).to(equal(NSDate(timeIntervalSinceReferenceDate: 10)))
                expect(article.summary).to(equal("summary"))
                expect(article.content).to(equal("content"))
                expect(article.author).to(equal("me"))
                expect(article.identifier).to(equal("0xDEADBEEF"))
            }

            context("when the item title is nil") {
                beforeEach {
                    item = Muon.Article()
                }
                context("and the article title has not previously been set") {
                    beforeEach {
                        article.title = nil
                        do {
                            try ctx.save()
                        } catch _ {
                        }
                    }
                    it("should set the article title to 'unknown'") {
                        DataUtility.updateArticle(article, item: item)
                        expect(article.title).to(equal("unknown"))
                    }
                }
                context("and the article title has previously been set") {
                    beforeEach {
                        article.title = "a title"
                        do {
                            try ctx.save()
                        } catch _ {
                        }
                    }
                    it("should not change the title") {
                        DataUtility.updateArticle(article, item: item)
                        expect(article.title).to(equal("a title"))
                    }
                }
            }

            context("when the article has just been created") {
                it("should set 'read' to false") {
                    article.read = true
                    do {
                        try ctx.save()
                    } catch _ {
                    }
                    DataUtility.updateArticle(article, item: item)
                    expect(article.read).to(beFalsy())
                }
            }
        }

        describe("insertEnclosureFromItem:article:") {
            let enclosure = Muon.Enclosure(url: NSURL(string: "http://example.com/enclosure.txt")!, length: 1234, type: "text/text")

            var article: CoreDataArticle! = nil

            beforeEach {
                article = createArticle(ctx)
            }

            context("when the article has an existing enclosure for this item") {
                beforeEach {
                    let enc = createEnclosure(ctx)
                    enc.article = article

                    enc.url = "http://example.com/enclosure.txt"
                    enc.kind = "text/text"

                    do {
                        try ctx.save()
                    } catch _ {
                    }
                }

                it("should not insert another enclosure item") {
                    expect(article.enclosures.count).to(equal(1))

                    DataUtility.insertEnclosureFromItem(enclosure, article: article)

                    expect(article.enclosures.count).to(equal(1))
                }
            }

            context("when the article does not have an existing enclosure for this item") {
                it("should insert an enclosure object into the article's enclosures set") {
                    DataUtility.insertEnclosureFromItem(enclosure, article: article)

                    expect(article.enclosures.count).to(equal(1))
                    if let enclosure = article.enclosures.first {
                        expect(enclosure.url).to(equal("http://example.com/enclosure.txt"))
                        expect(enclosure.kind).to(equal("text/text"))
                    } else {
                        expect(false).to(beTruthy())
                    }
                }
            }
        }

        describe("entities:matchingPredicate:managedObjectContext:sortDescriptors") {
            beforeEach {
                feed.title = "example"
                feed.summary = "example"
                let otherFeed = createFeed(ctx)
                otherFeed.title = "example"
                otherFeed.summary = "other"
                do {
                    try ctx.save()
                } catch _ {
                }
            }

            it("should return all objects that match the given predicate") {
                let predicate = NSPredicate(format: "title = %@", "example")
                let ret = DataUtility.entities("Feed", matchingPredicate: predicate, managedObjectContext: ctx)
                expect(ret.count).to(equal(2))
            }

            it("should sort the results if you ask it to") {
                let predicate = NSPredicate(format: "title = %@", "example")
                let sortDescriptor = NSSortDescriptor(key: "summary", ascending: true)
                let ret = DataUtility.entities("Feed", matchingPredicate: predicate, managedObjectContext: ctx, sortDescriptors: [sortDescriptor])
                expect(ret.first?.valueForKey("summary") as? String).to(equal("example"))
                expect(ret.last?.valueForKey("summary") as? String).to(equal("other"))
            }
        }

        describe("feedsWithPredicate:managedObjectContext:sortDescriptors") {
            var otherFeed : CoreDataFeed! = nil
            beforeEach {
                feed.title = "example"
                feed.summary = "example"
                otherFeed = createFeed(ctx)
                otherFeed.title = "example"
                otherFeed.summary = "other"
                do {
                    try ctx.save()
                } catch _ {
                }
            }

            it("should return all feeds that match the given predicate") {
                let predicate = NSPredicate(format: "title = %@", "example")
                let ret = DataUtility.feedsWithPredicate(predicate, managedObjectContext: ctx)
                expect(ret.count).to(equal(2))
            }

            it("should sort the results if you ask it to") {
                let predicate = NSPredicate(format: "title = %@", "example")
                let sortDescriptor = NSSortDescriptor(key: "summary", ascending: true)
                let ret = DataUtility.feedsWithPredicate(predicate, managedObjectContext: ctx, sortDescriptors: [sortDescriptor])
                expect(ret.first?.summary).to(equal("example"))
                expect(ret.last?.summary).to(equal("other"))
            }
        }

        describe("articlesWithPredicate:managedObjectContext:sortDescriptors") {

            var article : CoreDataArticle! = nil
            var otherArticle : CoreDataArticle! = nil
            beforeEach {
                article = createArticle(ctx)
                article.title = "example"
                article.summary = "example"
                otherArticle = createArticle(ctx)
                otherArticle.title = "example"
                otherArticle.summary = "other"
                do {
                    try ctx.save()
                } catch _ {
                }
            }

            it("should return all articles that match the given predicate") {
                let predicate = NSPredicate(format: "title = %@", "example")
                let ret = DataUtility.articlesWithPredicate(predicate, managedObjectContext: ctx)
                expect(ret.count).to(equal(2))
            }

            it("should sort the results if you ask it to") {
                let predicate = NSPredicate(format: "title = %@", "example")
                let sortDescriptor = NSSortDescriptor(key: "summary", ascending: true)
                let ret = DataUtility.articlesWithPredicate(predicate, managedObjectContext: ctx, sortDescriptors: [sortDescriptor])
                expect(ret.first?.summary).to(equal("example"))
                expect(ret.last?.summary).to(equal("other"))
            }
        }
    }
}
