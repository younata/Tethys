import Foundation
import CoreData
import Muon
#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

internal protocol DataUtilityType: class {
    func updateFeed(feed: CoreDataFeed, info: Muon.Feed)
    func updateFeedImage(feed: CoreDataFeed, info: Muon.Feed, urlSession: NSURLSession)
    func updateArticle(article: CoreDataArticle, item: Muon.Article)
    func insertEnclosureFromItem(item: Muon.Enclosure, article: CoreDataArticle)

    func entities(entity: String,
        matchingPredicate predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        callback: [NSManagedObject] -> Void)

    func entities(entity: String,
        matchingPredicate predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        mapper: (NSManagedObject) -> (NSObject?),
        callback: [NSObject] -> Void)

    func feedsWithPredicate(predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        callback: [Feed] -> Void)

    func articlesWithPredicate(predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        callback: [Article] -> Void)
}

internal class DataUtility: DataUtilityType {
    init() {}

    func updateFeed(feed: CoreDataFeed, info: Muon.Feed) {
        let summary: String
        let data = info.description.dataUsingEncoding(NSUTF8StringEncoding,
            allowLossyConversion: false)!
        let options = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType]
        do {
            let aString = try NSAttributedString(data: data, options: options,
                documentAttributes: nil)
                summary = aString.string
        } catch _ {
            summary = info.description
        }

        feed.managedObjectContext?.performBlock {
            feed.title = info.title
            feed.summary = summary
            let _ = try? feed.managedObjectContext?.save()
        }
    }

    func updateFeedImage(feed: CoreDataFeed, info: Muon.Feed, urlSession: NSURLSession) {
        if let imageURL = info.imageURL where feed.image == nil {
            urlSession.dataTaskWithURL(imageURL) {data, _, error in
                if error != nil {
                    return
                }
                if let d = data, image = Image(data: d) {
                    feed.managedObjectContext?.performBlock {
                        feed.image = image
                        let _ = try? feed.managedObjectContext?.save()
                    }
                }
            }.resume()
        }
    }

    func updateArticle(article: CoreDataArticle, item: Muon.Article) {
        let characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        let author = item.authors.map({ author in
            if let email = author.email {
                return "\(author.name) <\(email)>"
            }
            return author.name
        }).joinWithSeparator(", ")

        article.managedObjectContext?.performBlock {
            article.title = (item.title ?? article.title ?? "unknown").stringByTrimmingCharactersInSet(characterSet)
            article.link = item.link?.absoluteString ?? ""
            if article.published == nil {
                article.read = false
                article.published = item.published ?? NSDate()
            } else {
                article.published = item.published ?? article.published
            }
            article.updatedAt = item.updated
            article.summary = item.description
            article.content = item.content

            article.author = author
            article.identifier = item.guid

            let _ = try? article.managedObjectContext?.save()
        }
    }

    func insertEnclosureFromItem(item: Muon.Enclosure, article: CoreDataArticle) {
        let url = item.url.absoluteString
        for enclosure in article.enclosures {
            if (enclosure.valueForKey("url") as? NSObject) == url {
                return
            }
        }

        article.managedObjectContext?.performBlock {
            let entityDescription = NSEntityDescription.entityForName("Enclosure",
                inManagedObjectContext: article.managedObjectContext!)!
            let enclosure = CoreDataEnclosure(entity: entityDescription,
                insertIntoManagedObjectContext: article.managedObjectContext!)
            enclosure.url = url
            enclosure.kind = item.type
            enclosure.article = article
        }
    }

    // Callback is not guaranteed to be on the main thread
    func entities(entity: String,
        matchingPredicate predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        callback: [NSManagedObject] -> Void) {
            let request = NSFetchRequest()
            request.entity = NSEntityDescription.entityForName(entity,
                inManagedObjectContext: managedObjectContext)
            request.predicate = predicate

            managedObjectContext.performBlock {
                do {
                    if let ret = try managedObjectContext.executeFetchRequest(request) as? [NSManagedObject] {
                        callback(ret)
                        return
                    }
                } catch { }
            }
    }

    // callback not guaranteed to be on the main thread
    func entities(entity: String,
        matchingPredicate predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        mapper: (NSManagedObject) -> (NSObject?),
        callback: [NSObject] -> Void) {
            let request = NSFetchRequest()
            request.entity = NSEntityDescription.entityForName(entity,
                inManagedObjectContext: managedObjectContext)
            request.predicate = predicate

            managedObjectContext.performBlock {
                do {
                    if let ret = try managedObjectContext.executeFetchRequest(request) as? [NSManagedObject] {
                        let entities = ret.reduce(Array<NSObject>()) {
                            if let obj = mapper($1) {
                                return $0 + [obj]
                            }
                            return $0
                        }
                        callback(entities)
                    }
                } catch { }
            }
    }

    func feedsWithPredicate(predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        callback: [Feed] -> Void) {
            self.entities("Feed",
                matchingPredicate: predicate,
                managedObjectContext: managedObjectContext,
                mapper: {managedObject in
                    guard let coreDataFeed = managedObject as? CoreDataFeed else {
                        return nil
                    }
                    return Feed(feed: coreDataFeed)
                },
                callback: {feedObjects in
                    callback(feedObjects as? [Feed] ?? [])
                })
    }

    func articlesWithPredicate(predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        callback: [Article] -> Void) {
            self.entities("Article",
                matchingPredicate: predicate,
                managedObjectContext: managedObjectContext,
                mapper: {managedObject in
                    guard let coreDataArticle = managedObject as? CoreDataArticle else {
                        return nil
                    }
                    return Article(article: coreDataArticle, feed: nil)
                },
                callback: {articleObjects in
                    callback(articleObjects as? [Article] ?? [])
                })
    }
}
