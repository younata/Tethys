import Foundation
import CoreData

class DataUtility {
    // Just a collection of class functions, grouped under a class for namespacing reasons
    class func updateFeed(feed: Feed, info: MWFeedInfo, items: [MWFeedItem], context ctx: NSManagedObjectContext, dataManager: DataManager) {
        let predicate = NSPredicate(format: "url = %@", feed.url)!

        var summary : String = ""
        if let s = info.summary {
            let data = s.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            let options = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType]
            summary = s
            if let aString = NSAttributedString(data: data, options: options, documentAttributes: nil, error: nil) {
                summary = aString.string
            }
        }
        if let feed = dataManager.entities("Feed", matchingPredicate: predicate, managedObjectContext: ctx).last as? Feed {
            feed.title = info.title
        } else {
            let feed = (NSEntityDescription.insertNewObjectForEntityForName("Feed", inManagedObjectContext: ctx) as Feed)
            feed.title = info.title
        }

        feed.summary = summary
        for item in items {
            let article = dataManager.upsertArticle(item, context: ctx)
            feed.addArticlesObject(article)
            article.feed = feed
        }
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
}
