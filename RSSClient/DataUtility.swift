import Foundation
import CoreData
import Muon
#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

internal class DataUtility {
    // Just a collection of class functions, grouped under a class for namespacing reasons
    internal class func updateFeed(feed: CoreDataFeed, info: Muon.Feed) {
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
        feed.title = info.title

        feed.summary = summary
    }

    internal class func updateFeedImage(feed: CoreDataFeed, info: Muon.Feed, urlSession: NSURLSession) {
        if let imageURL = info.imageURL where feed.image == nil {
            urlSession.dataTaskWithURL(imageURL) {data, _, error in
                if error != nil {
                    return
                }
                if let d = data {
                    if let image = Image(data: d) {
                        feed.managedObjectContext?.performBlockAndWait {
                            feed.image = image
                            do {
                                try feed.managedObjectContext?.save()
                            } catch {}
                        }
                    }
                }
            }.resume()
        }
    }

    internal class func updateArticle(article: CoreDataArticle, item: Muon.Article) {
        article.title = (item.title ?? article.title ?? "unknown").stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
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
        let author = item.authors.map({ author in
            if let email = author.email {
                return "\(author.name) <\(email)>"
            }
            return author.name
        }).joinWithSeparator(", ")
        article.author = author
        article.identifier = item.guid
    }

    internal class func insertEnclosureFromItem(item: Muon.Enclosure, article: CoreDataArticle) {
        let url = item.url.absoluteString
        for enclosure in article.enclosures {
            if (enclosure.valueForKey("url") as? NSObject) == url {
                return
            }
        }

        let entityDescription = NSEntityDescription.entityForName("Enclosure",
            inManagedObjectContext: article.managedObjectContext!)!
        let enclosure = CoreDataEnclosure(entity: entityDescription,
            insertIntoManagedObjectContext: article.managedObjectContext!)
        enclosure.url = url
        enclosure.kind = item.type
        enclosure.article = article
    }

    internal class func entities(entity: String,
        matchingPredicate predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        sortDescriptors: [NSSortDescriptor]) -> [NSManagedObject] {
            let request = NSFetchRequest()
            request.entity = NSEntityDescription.entityForName(entity,
                inManagedObjectContext: managedObjectContext)
            request.predicate = predicate
            request.sortDescriptors = sortDescriptors

            var entities = Array<NSManagedObject>()

            managedObjectContext.performBlockAndWait {
                do {
                    if let ret = try managedObjectContext.executeFetchRequest(request) as? [NSManagedObject] {
                        entities = ret
                        return
                    }
                } catch { }
            }
            return entities
    }

    internal class func entities(entity: String,
        matchingPredicate predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        sortDescriptors: [NSSortDescriptor],
        mapper: (NSManagedObject) -> (NSObject?)) -> [NSObject] {
            let request = NSFetchRequest()
            request.entity = NSEntityDescription.entityForName(entity,
                inManagedObjectContext: managedObjectContext)
            request.predicate = predicate
            request.sortDescriptors = sortDescriptors

            var entities = Array<NSObject>()

            managedObjectContext.performBlockAndWait {
                do {
                    if let ret = try managedObjectContext.executeFetchRequest(request) as? [NSManagedObject] {
                        entities = ret.reduce(Array<NSObject>()) {
                            if let obj = mapper($1) {
                                return $0 + [obj]
                            }
                            return $0
                        }
                        return
                    }
                } catch { }
            }
            return entities
    }

    internal class func feedsWithPredicate(predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        sortDescriptors: [NSSortDescriptor] = []) -> [Feed] {
            return DataUtility.entities("Feed", matchingPredicate: predicate, managedObjectContext: managedObjectContext, sortDescriptors: sortDescriptors) {managedObject in
                guard let coreDataFeed = managedObject as? CoreDataFeed else {
                    return nil
                }
                return Feed(feed: coreDataFeed)
            } as? [Feed] ?? []
    }

    internal class func articlesWithPredicate(predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        sortDescriptors: [NSSortDescriptor] = []) -> [Article] {
            return DataUtility.entities("Article", matchingPredicate: predicate, managedObjectContext: managedObjectContext, sortDescriptors: sortDescriptors) {managedObject in
                guard let coreDataArticle = managedObject as? CoreDataArticle else {
                    return nil
                }
                return Article(article: coreDataArticle, feed: nil)
            } as? [Article] ?? []
    }
}
