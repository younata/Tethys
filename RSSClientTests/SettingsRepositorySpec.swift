import Quick
import Nimble
import rNews

private class FakeSettingsRepositorySubscriber: NSObject, SettingsRepositorySubscriber {
    private var didCallChangeSetting = false
    private func didChangeSetting(_: SettingsRepository) {
        didCallChangeSetting = true
    }
}

class SettingsRepositorySpec: QuickSpec {
    override func spec() {
        var subject: SettingsRepository! = nil
        var userDefaults: FakeUserDefaults! = nil
        var subscriber: FakeSettingsRepositorySubscriber! = nil

        beforeEach {
            userDefaults = FakeUserDefaults()
            subject = SettingsRepository(userDefaults: userDefaults)

            subscriber = FakeSettingsRepositorySubscriber()
            subject.addSubscriber(subscriber)
            subscriber.didCallChangeSetting = false
        }

        it("calls 'didChangeSetting' on the new subscriber whenever it's added") {
            let newSubscriber = FakeSettingsRepositorySubscriber()
            subject.addSubscriber(newSubscriber)
            expect(newSubscriber.didCallChangeSetting) == true
            expect(subscriber.didCallChangeSetting) == false
        }

        describe("Query Feeds") {
            it("are initially disabled") {
                expect(subject.queryFeedsEnabled) == false
            }

            describe("when set") {
                beforeEach {
                    subject.queryFeedsEnabled = true
                }

                it("records the result") {
                    expect(subject.queryFeedsEnabled) == true
                }

                it("notifies subscribers") {
                    expect(subscriber.didCallChangeSetting) == true
                }

                it("persists if userDefaults is not nil") {
                    let newRepository = SettingsRepository(userDefaults: userDefaults)
                    expect(newRepository.queryFeedsEnabled) == true
                }
            }
        }
    }
}