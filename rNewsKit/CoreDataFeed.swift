import CoreData

@objc
class CoreDataFeed: NSManagedObject {
    @NSManaged var title: String?
    @NSManaged var url: String?
    @NSManaged var summary: String?
    @NSManaged var query: String?
    @NSManaged var tags: [String]
    @NSManaged var waitPeriod: NSNumber?
    @NSManaged var remainingWait: NSNumber?
    @NSManaged var articles: Set<CoreDataArticle>
    @NSManaged var image: AnyObject?

    var waitPeriodInt: Int {
        get {
            return self.waitPeriod?.integerValue ?? 0
        }
        set {
            self.waitPeriod = NSNumber(integer: newValue)
        }
    }

    var remainingWaitInt: Int {
        get {
            return self.remainingWait?.integerValue ?? 0
        }
        set {
            self.remainingWait = NSNumber(integer: newValue)
        }
    }
}
