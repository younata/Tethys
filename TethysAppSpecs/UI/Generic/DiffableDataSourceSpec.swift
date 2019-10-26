import Quick
import Nimble

@testable import Tethys

final class DiffableDataSourceSpec: QuickSpec {
    override func spec() {
        it("is only necessary because UITableViewDiffableDataSource does not allow editing rows") {
            let tableView = UITableView()
            let diffableDataSource = UITableViewDiffableDataSource<Int, Int>(tableView: tableView) { tableView, indexPath, _ in
                return nil
            }

            expect(diffableDataSource.tableView(tableView, canEditRowAt: IndexPath(row: 0, section: 0))).to(beFalse(), description: "Remove DiffableDataSource once this test fails")
        }

        it("allows editing rows") {
            let tableView = UITableView()
            let diffableDataSource = DiffableDataSource<Int, Int>(tableView: tableView) { tableView, indexPath, _ in
                return nil
            }

            expect(diffableDataSource.tableView(tableView, canEditRowAt: IndexPath(row: 0, section: 0))).to(beTrue())
        }
    }
}
