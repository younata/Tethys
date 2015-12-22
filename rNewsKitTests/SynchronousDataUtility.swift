import Foundation
#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

import CoreData
import Muon
@testable import rNewsKit

class SynchronousDataUtility: DataUtilityType {
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

        feed.managedObjectContext?.performBlockAndWait {
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
                    feed.managedObjectContext?.performBlockAndWait {
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

        article.managedObjectContext?.performBlockAndWait {
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

        article.managedObjectContext?.performBlockAndWait {
            let entityDescription = NSEntityDescription.entityForName("Enclosure",
                inManagedObjectContext: article.managedObjectContext!)!
            let enclosure = CoreDataEnclosure(entity: entityDescription,
                insertIntoManagedObjectContext: article.managedObjectContext!)
            enclosure.url = url
            enclosure.kind = item.type
            enclosure.article = article
        }
    }

    func entities(entity: String,
        matchingPredicate predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        callback: [NSManagedObject] -> Void) {
            let request = NSFetchRequest()
            request.entity = NSEntityDescription.entityForName(entity,
                inManagedObjectContext: managedObjectContext)
            request.predicate = predicate

            var returnObjects = [NSManagedObject]()

            managedObjectContext.performBlockAndWait {
                do {
                    if let ret = try managedObjectContext.executeFetchRequest(request) as? [NSManagedObject] {
                        returnObjects = ret
                        return
                    }
                } catch { }
            }
            callback(returnObjects)
    }

    func synchronousEntities(entity: String,
        matchingPredicate predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext) -> [NSManagedObject] {
            var ret = [NSManagedObject]()
            self.entities(entity, matchingPredicate: predicate, managedObjectContext: managedObjectContext) { ret = $0 }
            return ret
    }

    func entities(entity: String,
        matchingPredicate predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        mapper: (NSManagedObject) -> (NSObject?),
        callback: [NSObject] -> Void) {
            let request = NSFetchRequest()
            request.entity = NSEntityDescription.entityForName(entity,
                inManagedObjectContext: managedObjectContext)
            request.predicate = predicate

            var returnObjects = [NSObject]()

            managedObjectContext.performBlockAndWait {
                do {
                    if let ret = try managedObjectContext.executeFetchRequest(request) as? [NSManagedObject] {
                        returnObjects = ret.reduce(Array<NSObject>()) {
                            if let obj = mapper($1) {
                                return $0 + [obj]
                            }
                            return $0
                        }
                    }
                } catch { }
            }

            callback(returnObjects)
    }

    func feedsWithPredicate(predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        callback: [rNewsKit.Feed] -> Void) {
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
                    callback(feedObjects as? [rNewsKit.Feed] ?? [])
            })
    }

    func synchronousFeedsWithPredicate(predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext) -> [rNewsKit.Feed] {
            var ret: [rNewsKit.Feed] = []
            self.feedsWithPredicate(predicate, managedObjectContext: managedObjectContext) { ret = $0 }
            return ret
    }

    func articlesWithPredicate(predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        callback: [rNewsKit.Article] -> Void) {
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
                    callback(articleObjects as? [rNewsKit.Article] ?? [])
            })
    }

    func synchronousArticlesWithPredicate(predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext) -> [rNewsKit.Article] {
            var ret: [rNewsKit.Article] = []
            self.articlesWithPredicate(predicate, managedObjectContext: managedObjectContext) { ret = $0 }
            return ret
    }
}