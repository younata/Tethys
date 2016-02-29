import Quick
import Nimble

import rNews

class MigrationViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: MigrationViewController!
        var migrationUseCase: FakeMigrationUseCase!
        var themeRepository: FakeThemeRepository!
        var mainQueue: FakeOperationQueue!

        beforeEach {
            migrationUseCase = FakeMigrationUseCase()
            themeRepository = FakeThemeRepository()
            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            subject = MigrationViewController(migrationUseCase: migrationUseCase, themeRepository: themeRepository, mainQueue: mainQueue)

            subject.view.layoutIfNeeded()
        }

        it("adds a subscriber to the migration use case") {
            expect(migrationUseCase.addSubscriberCallCount) == 1
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("changes the background color") {
                expect(subject.view.backgroundColor) == themeRepository.backgroundColor
            }

            it("changes the label text") {
                expect(subject.label.textColor) == themeRepository.textColor
            }
        }

        it("sets the label's text") {
            expect(subject.label.text) == "Optimizing your database, hang tight"
        }

        it("updates the progress bar as the migration use case progress updates") {
            migrationUseCase.addSubscriberArgsForCall(0).migrationUseCase(migrationUseCase, didUpdateProgress: 0.5)

            expect(subject.progressBar.progress).to(beCloseTo(0.5))
        }
    }
}
