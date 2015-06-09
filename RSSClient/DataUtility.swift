import Foundation
import CoreData
import Alamofire
import Muon

public class DataUtility {
    // Just a collection of class functions, grouped under a class for namespacing reasons
    public class func updateFeed(feed: CoreDataFeed, info: Muon.Feed) {
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

    public class func updateFeedImage(feed: CoreDataFeed, info: Muon.Feed, manager: Alamofire.Manager) {
        if let imageURL = info.imageURL where feed.image == nil {
            manager.request(.GET, imageURL).response {(_, _, data, error) in
                if error != nil {
                    return
                }
                if let d = data as? NSData {
                    if let image = Image(data: d) {
                        feed.image = image
                        do {
                            try feed.managedObjectContext?.save()
                        } catch _ {
                        }
                    }
                }
            }
        }
    }

    public class func updateArticle(article: CoreDataArticle, item: Muon.Article) {
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
        let author = ", ".join(item.authors.map { author in
            if let email = author.email {
                return "\(author.name) <\(author.email)>"
            }
            return author.name
        })
        article.author = author
        article.identifier = item.guid
    }

    public class func insertEnclosureFromItem(item: Muon.Enclosure, article: CoreDataArticle) {
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
        article.addEnclosuresObject(enclosure)
    }

    public class func entities(entity: String,
        matchingPredicate predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        sortDescriptors: [NSSortDescriptor] = []) -> [NSManagedObject] {
            let request = NSFetchRequest()
            request.entity = NSEntityDescription.entityForName(entity,
                inManagedObjectContext: managedObjectContext)
            request.predicate = predicate
            request.sortDescriptors = sortDescriptors

            let error: NSError? = nil
            if let ret = managedObjectContext.executeFetchRequest(request) as? [NSManagedObject] {
                    return ret
            }
            print("Error executing fetch request: \(error)")
            return []
    }

    public class func feedsWithPredicate(predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        sortDescriptors: [NSSortDescriptor] = []) -> [Feed] {
            let feeds = DataUtility.entities("Feed",
                matchingPredicate: predicate,
                managedObjectContext: managedObjectContext,
                sortDescriptors: sortDescriptors) as? [CoreDataFeed] ?? []
            return feeds.map {
                Feed(feed: $0)
            }
    }

    public class func articlesWithPredicate(predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        sortDescriptors: [NSSortDescriptor] = []) -> [Article] {
            let articles = DataUtility.entities("Article",
                matchingPredicate: predicate,
                managedObjectContext: managedObjectContext,
                sortDescriptors: sortDescriptors) as? [CoreDataArticle] ?? []
            return articles.map {
                Article(article: $0, feed: nil)
            }
    }
}
