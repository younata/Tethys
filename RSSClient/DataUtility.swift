import Foundation
import CoreData
import Alamofire
import Muon

class DataUtility {
    // Just a collection of class functions, grouped under a class for namespacing reasons
    class func updateFeed(feed: CoreDataFeed, info: Muon.Feed) {
        let summary : String
        let data = info.description.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let options = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType]
        if let aString = NSAttributedString(data: data, options: options, documentAttributes: nil, error: nil) {
            summary = aString.string
        } else {
            summary = info.description
        }
        feed.title = info.title

        feed.summary = summary
    }

    class func updateFeedImage(feed: CoreDataFeed, info: Muon.Feed, manager: Alamofire.Manager) {
        if let imageURL = info.imageURL where feed.image == nil {
            manager.request(.GET, imageURL).response {(_, _, data, error) in
                if error != nil {
                    return
                }
                if let d = data as? NSData {
                    if let image = Image(data: d) {
                        feed.image = image
                        feed.managedObjectContext?.save(nil)
                    }
                }
            }
        }
    }

    class func updateArticle(article: CoreDataArticle, item: Muon.Article) {
        article.title = item.title ?? article.title ?? "unknown"
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
        let author = join(", ", item.authors.map { author in
            if let email = author.email {
                return "\(author.name) <\(author.email)>"
            }
            return author.name
        })
        article.author = author
        article.identifier = item.guid
    }

    class func insertEnclosureFromItem(item: Muon.Enclosure, article: CoreDataArticle) {
        let url = item.url.absoluteString
        for enclosure in article.enclosures {
            if (enclosure.valueForKey("url") as? NSObject) == url {
                return
            }
        }

        let entityDescription = NSEntityDescription.entityForName("Enclosure", inManagedObjectContext: article.managedObjectContext!)!
        let enclosure = CoreDataEnclosure(entity: entityDescription, insertIntoManagedObjectContext: article.managedObjectContext!)
        enclosure.url = url
        enclosure.kind = item.type
        enclosure.article = article
        article.addEnclosuresObject(enclosure)
    }

    class func entities(entity: String, matchingPredicate predicate: NSPredicate, managedObjectContext: NSManagedObjectContext, sortDescriptors: [NSSortDescriptor] = []) -> [NSManagedObject] {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName(entity, inManagedObjectContext: managedObjectContext)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        var error : NSError? = nil
        if let ret = managedObjectContext.executeFetchRequest(request, error: &error) as? [NSManagedObject] {
            return ret
        }
        println("Error executing fetch request: \(error)")
        return []
    }

    class func feedsWithPredicate(predicate: NSPredicate, managedObjectContext: NSManagedObjectContext, sortDescriptors: [NSSortDescriptor] = []) -> [Feed] {
        return map(DataUtility.entities("Feed", matchingPredicate: predicate, managedObjectContext: managedObjectContext, sortDescriptors: []) as? [CoreDataFeed] ?? []) {
            Feed(feed: $0)
        }
    }

    class func articlesWithPredicate(predicate: NSPredicate, managedObjectContext: NSManagedObjectContext, sortDescriptors: [NSSortDescriptor] = []) -> [Article] {
        return map(DataUtility.entities("Article", matchingPredicate: predicate, managedObjectContext: managedObjectContext, sortDescriptors: []) as? [CoreDataArticle] ?? []) {
            Article(article: $0, feed: nil)
        }
    }
}
