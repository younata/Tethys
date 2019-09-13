import Quick
import Nimble
import Tethys

class ActionableTableViewSpec: QuickSpec {
    override func spec() {
        var subject: ActionableTableView!

        beforeEach {
            subject = ActionableTableView(frame: CGRect.zero)
        }

        describe("theming") {
            it("sets the tableView") {
                expect(subject.tableView.backgroundColor).to(equal(Theme.backgroundColor))
                expect(subject.tableView.separatorColor).to(equal(Theme.separatorColor))
            }
        }
    }
}
