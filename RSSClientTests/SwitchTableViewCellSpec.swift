import Quick
import Nimble
import rNews

class SwitchTableViewCellSpec: QuickSpec {
    override func spec() {
        var subject: SwitchTableViewCell! = nil
        var themeRepository: ThemeRepository! = nil

        beforeEach {
            subject = SwitchTableViewCell(style: .default, reuseIdentifier: nil)
            themeRepository = ThemeRepository(userDefaults: nil)
            subject.themeRepository = themeRepository
        }

        it("calls onTapSwitch whenever the switch changes value") {
            var called = false
            subject.onTapSwitch = {aSwitch in
                called = true
                expect(aSwitch).to(beIdenticalTo(subject.theSwitch))
            }
            subject.theSwitch.sendActions(for: .valueChanged)
            expect(called) == true
        }

        describe("on theme changes") {
            beforeEach {
                themeRepository.theme = .dark
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
