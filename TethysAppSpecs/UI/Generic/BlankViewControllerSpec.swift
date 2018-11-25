import Quick
import Nimble

import Tethys

final class BlankViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: BlankViewController!

        var navigationController: UINavigationController!

        var themeRepository: ThemeRepository!

        beforeEach {
            themeRepository = ThemeRepository(userDefaults: nil)

            subject = BlankViewController(themeRepository: themeRepository)

            navigationController = UINavigationController(rootViewController: subject)

            subject.view.layoutIfNeeded()
        }

        describe("responding to theme changes") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("sets the background color") {
                expect(subject.view.backgroundColor) == ThemeRepository.Theme.dark.backgroundColor
            }

            it("sets the navigationController's background") {
                expect(navigationController.navigationBar.barStyle) == ThemeRepository.Theme.dark.barStyle
            }
        }
    }
}
