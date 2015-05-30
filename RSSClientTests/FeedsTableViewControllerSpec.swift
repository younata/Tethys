import Quick
import Nimble
import Ra
import rNews

class FeedsTableViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FeedsTableViewController! = nil
        var injector : Injector! = nil
        var dataManager: DataManagerMock! = nil

        beforeEach {
            injector = Injector()
            dataManager = DataManagerMock()
            injector.bind(DataManager.self, to: dataManager)

            subject = injector.create(FeedsTableViewController.self) as! FeedsTableViewController
        }

        describe("loading feeds") {

        }
    }
}
