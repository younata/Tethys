import Quick
import Nimble
import Tethys

class ActionableTableViewSpec: QuickSpec {
    override func spec() {
        var subject: ActionableTableView!
        var themeRepository: ThemeRepository!

        beforeEach {
            themeRepository = ThemeRepository(userDefaults: nil)
            subject = ActionableTableView(frame: CGRect.zero)
            subject.themeRepository = themeRepository
        }

        describe("listening to theme repository updates") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("should update the tableView") {
                expect(subject.tableView.backgroundColor) == themeRepository.backgroundColor
                expect(subject.tableView.separatorColor) == themeRepository.textColor
            }

            it("should update the tableView scroll indicator style") {
                expect(subject.tableView.indicatorStyle) == themeRepository.scrollIndicatorStyle
            }
        }
    }
}
