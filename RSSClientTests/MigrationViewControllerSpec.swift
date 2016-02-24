import Quick
import Nimble

import rNews

class MigrationViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: MigrationViewController!

        var migrationUseCase: FakeMigrationUseCase!

        beforeEach {
            migrationUseCase = FakeMigrationUseCase()
            subject = MigrationViewController(migrationUseCase: migrationUseCase)

            subject.view.layoutIfNeeded()
        }

        it("asks the use case to begin") {
            expect(migrationUseCase.beginMigrationCallCount) == 1
        }
    }
}
