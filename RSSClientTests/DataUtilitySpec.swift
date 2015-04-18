import Quick
import Nimble
import Foundation
import Alamofire

class DataUtilitySpec: QuickSpec {
    override func spec() {
        let ctx = managedObjectContext()
        var feed : Feed! = nil

        let info = MWFeedInfo()

        beforeEach {
            feed = createFeed(ctx)
        }

        describe("updateFeed:info:") {
            beforeEach {
                info.title = "example feed"
                info.link = "http://example.com"
                info.summary = "example"
                info.url = NSURL(string: "http://example.com")
info.imageURL = nil
            }
            it("should update the feed accordingly") {
                DataUtility.updateFeed(feed, info: info)

                expect(feed.title).to(equal("example feed"))
                expect(feed.summary).to(equal("example"))
            }
        }

        describe("updateFeedImage:info:manager") {
            beforeEach {
                info.title = "example"
                info.link = "http://example.com"
                info.summary = "example"
                info.url = NSURL(string: "http://example.com")
                info.imageURL = "https://raw.githubusercontent.com/younata/RSSClient/master/RSSClient/Images.xcassets/AppIcon.appiconset/Icon@2x.png"
            }

            context("when the feed doesn't have an existing image") {
                it("should download the image pointed at by info.imageURL and set it as the feed image") {
                    DataUtility.updateFeedImage(feed, info: info, manager: Alamofire.Manager.sharedInstance)

                    expect(feed.hasChanges).toEventually(beTruthy(), timeout: 60)
                    expect(feed.feedImage()).toEventuallyNot(beNil(), timeout: 60)
                }
            }
            context("when the feed has an existing image") {
                beforeEach {
                    feed.image = UIImage(named: "AppIcon60x60")
                    feed.managedObjectContext?.save(nil)
                }
                it("should not update the feed image") {
                    DataUtility.updateFeedImage(feed, info: info, manager: Manager.sharedInstance)

                    expect(feed.hasChanges).to(beFalsy())
                }
            }
        }

        describe("updateArticle:item:") {
            var article: Article! = nil
            let item = MWFeedItem()
            beforeEach {
                article = createArticle(ctx)
                ctx.save(nil)

                item.title = "example"
                item.link = "http://example.com"
                item.date = NSDate(timeIntervalSinceReferenceDate: 0)
                item.updated = NSDate(timeIntervalSinceReferenceDate: 10)
                item.summary = "summary"
                item.content = "content"
                item.author = "me"
                item.identifier = "0xDEADBEEF"
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
                    item.title = nil
                }
                context("and the article title has not previously been set") {
                    beforeEach {
                        article.title = nil
                        ctx.save(nil)
                    }
                    it("should set the article title to 'unknown'") {
                        DataUtility.updateArticle(article, item: item)
                        expect(article.title).to(equal("unknown"))
                    }
                }
                context("and the article title has previously been set") {
                    beforeEach {
                        article.title = "a title"
                        ctx.save(nil)
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
                    ctx.save(nil)
                    DataUtility.updateArticle(article, item: item)
                    expect(article.read).to(beFalsy())
                }
            }
        }

        describe("insertEnclosureFromItem:article:") {
            let enclosure = ["url": "http://example.com/enclosure.txt", "type": "text/text"]

            var article: Article! = nil

            beforeEach {
                article = createArticle(ctx)
            }

            context("when the article has an existing enclosure for this item") {
                beforeEach {
                    let enc = createEnclosure(ctx)
                    article.addEnclosuresObject(enc)
                    enc.article = article

                    enc.url = "http://example.com/enclosure.txt"
                    enc.kind = "text/text"

                    ctx.save(nil)
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
                    let enclosure = article.allEnclosures().first! as NSManagedObject
                    expect(enclosure.valueForKey("url") as? String).to(equal("http://example.com/enclosure.txt"))
                    expect(enclosure.valueForKey("kind") as? String).to(equal("text/text"))
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
                ctx.save(nil)
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
                expect(ret.first?.summary).to(equal("example"))
                expect(ret.last?.summary).to(equal("other"))
            }
        }
    }
}
