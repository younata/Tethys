import Quick
import Nimble
import rNews

class SwitchTableViewCellSpec: QuickSpec {
    override func spec() {
        var subject: SwitchTableViewCell! = nil
        var themeRepository: FakeThemeRepository! = nil

        beforeEach {
            subject = SwitchTableViewCell(style: .Default, reuseIdentifier: nil)
            themeRepository = FakeThemeRepository()
            subject.themeRepository = themeRepository
        }

        it("calls onTapSwitch whenever the switch changes value") {
            var called = false
            subject.onTapSwitch = {aSwitch in
                called = true
                expect(aSwitch).to(beIdenticalTo(subject.theSwitch))
            }
            subject.theSwitch.sendActionsForControlEvents(.ValueChanged)
            expect(called) == true
        }

        describe("on theme changes") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should change the background") {
                expect(subject.backgroundColor).to(equal(themeRepository.backgroundColor))
            }

            it("should change the textLabel's textColor") {
                expect(subject.textLabel?.textColor).to(equal(themeRepository.textColor))
            }
        }
    }
}