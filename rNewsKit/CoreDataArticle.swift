import CoreData

class CoreDataArticle: NSManagedObject {
    @NSManaged var title: String?
    @NSManaged var link: String?
    @NSManaged var summary: String?
    @NSManaged var author: String?
    @NSManaged var published: NSDate!
    @NSManaged var updatedAt: NSDate?
    @NSManaged var identifier: String?
    @NSManaged var content: String?
    @NSManaged var read: Bool
    @NSManaged var flags: [String]
    @NSManaged var feed: CoreDataFeed?
    @NSManaged var enclosures: Set<CoreDataEnclosure>
}
