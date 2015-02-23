import Quick
import Nimble
import Ra

class DataManagerSpec: QuickSpec {
    override func spec() {
        var subject : DataManager! = nil
        var injector : Ra.Injector! = nil
        beforeEach {
            injector = Ra.Injector()
            let dataHelper = CoreDataHelperMock()
            subject = DataManager()
            injector.bind(kMainManagedObjectContext, to: subject.managedObjectContext)
            injector.bind(kBackgroundManagedObjectContext, to: subject.backgroundObjectContext)
            let feedManager = FeedManagerMock()
            feedManager.feed = (dataHelper.createEntity("Feed") as Feed)
            injector.bind(FeedManager.self, to: feedManager)
        }
    }
}
