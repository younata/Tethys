import CoreData

class CoreDataEnclosure: NSManagedObject {
    @NSManaged var url: String?
    @NSManaged var kind: String?
    @NSManaged var data: NSData?
    @NSManaged var downloaded: Bool
    @NSManaged var article: CoreDataArticle?
}