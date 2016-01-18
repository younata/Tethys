import Nimble
import UIKit

public func equalColor(expectedColor: UIColor?) -> MatcherFunc<UIColor> {
    return MatcherFunc { actualExpression, failureMessage in
        guard let expectedColor = expectedColor else { return false }
        guard let colors = (try? actualExpression.evaluate())??.getRGB() else { return false }

        let expectedColors = expectedColor.getRGB()

        if fabs(colors.red - expectedColors.red) > 1e-6 {
            failureMessage.postfixMessage += " - (Red is off: Got \(colors.red), wanted \(expectedColors.red))"
            return false
        }
        if fabs(colors.green - expectedColors.green) > 1e-6 {
            failureMessage.postfixMessage += " - (Green is off: Got \(colors.green), wanted \(expectedColors.green))"
            return false
        }
        if fabs(colors.blue - expectedColors.blue) > 1e-6 {
            failureMessage.postfixMessage += " - (Blue is off: Got \(colors.blue), wanted \(expectedColors.blue))"
            return false
        }
        if fabs(colors.alpha - expectedColors.alpha) > 1e-6 {
            failureMessage.postfixMessage += " - (Alpha is off: Got \(colors.alpha), wanted \(expectedColors.alpha))"
            return false
        }
        return true
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