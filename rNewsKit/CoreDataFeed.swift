import CoreData

class CoreDataFeed: NSManagedObject {
    @NSManaged var title: String?
    @NSManaged var url: String?
    @NSManaged var summary: String?
    @NSManaged var query: String?
    @NSManaged var tags: [String]
    @NSManaged var waitPeriod: Int
    @NSManaged var remainingWait: Int
    @NSManaged var articles: Set<CoreDataArticle>
    @NSManaged var image: AnyObject?
}