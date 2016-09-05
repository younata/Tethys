import CoreData

class CoreDataArticle: NSManagedObject {
    @NSManaged var title: String?
    @NSManaged var link: String?
    @NSManaged var summary: String?
    @NSManaged var author: String?
    @NSManaged var published: Date!
    @NSManaged var updatedAt: Date?
    @NSManaged var identifier: String?
    @NSManaged var content: String?
    @NSManaged var read: Bool
    @NSManaged var estimatedReadingTime: NSNumber?
    @NSManaged var flags: [String]
    @NSManaged var feed: CoreDataFeed?
    @NSManaged var relatedArticles: Set<CoreDataArticle>
}
