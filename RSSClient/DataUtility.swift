import Foundation
import CoreData

class DataUtility {
    // Just a collection of class functions, grouped under a class for namespacing reasons
    class func updateFeed(feed: Feed, info: MWFeedInfo) {
        var summary : String = ""
        if let s = info.summary {
            let data = s.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            let options = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType]
            summary = s
            if let aString = NSAttributedString(data: data, options: options, documentAttributes: nil, error: nil) {
                summary = aString.string
            }
        }
        feed.title = info.title
        feed.url = info.url.absoluteString

        feed.summary = summary
    }

    class func updateFeedImage(feed: Feed, info: MWFeedInfo, manager: Manager) {
        if info.imageURL != nil && feed.feedImage() == nil {
            manager.request(.GET, info.imageURL).response {(_, _, data, error) in
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

    class func updateArticle(article: Article, item: MWFeedItem) {
        article.title = item.title ?? article.title ?? "unknown"
        article.link = item.link
        if article.published == nil {
            article.read = false
            article.published = item.date ?? NSDate()
        } else {
            article.published = item.date ?? article.published
        }
        article.updatedAt = item.updated
        article.summary = item.summary
        article.content = item.content
        article.author = item.author
        article.identifier = item.identifier
    }

    class func insertEnclosureFromItem(item: [String: AnyObject], article: Article) {
        let url = item["url"] as String?
        var found = false
        for enclosure in article.enclosures.allObjects {
            if enclosure.url == url {
                found = true
                break
            }
        }
        if !found {
            let type = item["type"] as String?

            let entityDescription = NSEntityDescription.entityForName("Enclosure", inManagedObjectContext: article.managedObjectContext!)!
            let enclosure = Enclosure(entity: entityDescription, insertIntoManagedObjectContext: article.managedObjectContext!)
            enclosure.url = url
            enclosure.kind = type
            enclosure.article = article
            article.addEnclosuresObject(enclosure)
        }
    }

    class func entities(entity: String, matchingPredicate predicate: NSPredicate, managedObjectContext: NSManagedObjectContext, sortDescriptors: [NSSortDescriptor] = []) -> [AnyObject] {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName(entity, inManagedObjectContext: managedObjectContext)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        var error : NSError? = nil
        if let ret = managedObjectContext.executeFetchRequest(request, error: &error) {
            return ret
        }
        println("Error executing fetch request: \(error)")
        return []
    }
}
