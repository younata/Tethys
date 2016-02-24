import Quick
import Nimble
import rNews

class MigrationUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: MigrationUseCase!
        var feedRepository: FakeFeedRepository!

        var subscriber: FakeMigrationUseCaseSubscriber!

        beforeEach {
            feedRepository = FakeFeedRepository()
            subject = DefaultMigrationUseCase(feedRepository: feedRepository)

            subscriber = FakeMigrationUseCaseSubscriber()

            subject.addSubscriber(subscriber)
        }

        describe("migrating") {
            beforeEach {
                subject.beginMigration()
            }

            it("tells the feed repository to perform any migrations necessary") {
                expect(feedRepository.perfomDatabaseUpdatesCallback).toNot(beNil())
            }

            it("informs subscribers when the migration finishes") {
                feedRepository.perfomDatabaseUpdatesCallback?()

                expect(subscriber.migrationUseCaseDidFinishCallCount) == 1
            }
        }
    }
}
