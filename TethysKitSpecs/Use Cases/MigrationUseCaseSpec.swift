import Quick
import Nimble
import WorkFlow
import TethysKit

class MigrationUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultMigrationUseCase!
        var feedRepository: FakeDatabaseUseCase!

        var subscriber: FakeMigrationUseCaseSubscriber!

        beforeEach {
            feedRepository = FakeDatabaseUseCase()
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

            it("informs subscribers when the migration progress updates") {
                feedRepository.performDatabaseUpdatesProgress?(1.0)

                expect(subscriber.migrationUseCaseDidUpdateProgressCallCount) == 1
                expect(subscriber.migrationUseCaseDidUpdateProgressArgsForCall(0).1) == 1.0
            }

            it("informs subscribers when the migration finishes") {
                feedRepository.perfomDatabaseUpdatesCallback?()

                expect(subscriber.migrationUseCaseDidFinishCallCount) == 1
            }
        }

        describe("as a WorkFlowComponent") {
            var didFinishWorkFlowComponent = false
            beforeEach {
                didFinishWorkFlowComponent = false

                subject.beginWork {
                    didFinishWorkFlowComponent = true
                }
            }

            it("begins the migration when beginWork is called") {
                expect(feedRepository.perfomDatabaseUpdatesCallback).toNot(beNil())
            }

            it("informs subscribers when the migration progress updates") {
                feedRepository.performDatabaseUpdatesProgress?(1.0)

                expect(subscriber.migrationUseCaseDidUpdateProgressCallCount) == 1
                expect(subscriber.migrationUseCaseDidUpdateProgressArgsForCall(0).1) == 1.0
            }

            it("calls the callback when the migration finishes") {
                feedRepository.perfomDatabaseUpdatesCallback?()

                expect(didFinishWorkFlowComponent) == true
            }
        }
    }
}
