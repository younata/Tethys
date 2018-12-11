import Nimble
import UIKit

public func equalColor(expectedColor: UIColor?) -> Predicate<UIColor> {
    return Predicate { expression in
        guard let expectedColor = expectedColor else {
            return PredicateResult(bool: false, message: ExpectationMessage.fail("Expected value was nil (use BeNil() to match nils)"))
        }
        let result: UIColor?
        do {
            result = try expression.evaluate()
        } catch let error {
            return PredicateResult(
                bool: false,
                message: .fail("Got \(error) trying to evaluate expression")
            )
        }
        guard let subject = result else {
            return PredicateResult(bool: false, message: ExpectationMessage.fail("subject was nil"))
        }
        let colors = subject.getRGB()

        let expectedColors = expectedColor.getRGB()

        var failingMessage = ExpectationMessage.fail("\(subject) not equal to \(expectedColor)")
        var shouldPass = true
        if abs(colors.red - expectedColors.red) > 1e-6 {
            shouldPass = false
            failingMessage = ExpectationMessage.details(failingMessage, "Red is off: Got \(colors.red), wanted \(expectedColors.red)")
        }
        if abs(colors.green - expectedColors.green) > 1e-6 {
            shouldPass = false
            failingMessage = ExpectationMessage.appends(failingMessage, "Green is off: Got \(colors.green), wanted \(expectedColors.green)")
        }
        if abs(colors.blue - expectedColors.blue) > 1e-6 {
            shouldPass = false
            failingMessage = ExpectationMessage.appends(failingMessage, "Blue is off: Got \(colors.blue), wanted \(expectedColors.blue)")
        }
        if abs(colors.alpha - expectedColors.alpha) > 1e-6 {
            shouldPass = false
            failingMessage = ExpectationMessage.appends(failingMessage, "Alpha is off: Got \(colors.alpha), wanted \(expectedColors.alpha)")
        }
        if shouldPass {
            return PredicateResult(
                bool: true,
                message: ExpectationMessage.fail("\(subject) is equal to \(expectedColor)")
            )
        }
        return PredicateResult(bool: false, message: failingMessage)
    }
}

extension UIColor {
    func getRGB() -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }
}
