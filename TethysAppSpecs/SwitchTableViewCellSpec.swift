import Quick
import Nimble
import Tethys

class SwitchTableViewCellSpec: QuickSpec {
    override func spec() {
        var subject: SwitchTableViewCell! = nil

        beforeEach {
            subject = SwitchTableViewCell(style: .default, reuseIdentifier: nil)
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

        describe("theming") {
            it("sets the background") {
                expect(subject.backgroundColor).to(equal(Theme.backgroundColor))
            }

            it("sets the textLabel's textColor") {
                expect(subject.textLabel?.textColor).to(equal(Theme.textColor))
            }
        }
    }
}
