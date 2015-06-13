import UIKit

public class TextFieldCell: UITableViewCell, UITextFieldDelegate {

    public lazy var textField: UITextField = {
        let textField = UITextField(forAutoLayout: ())
        textField.delegate = self
        textField.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        self.contentView.addSubview(textField)

        textField.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Right)
        return textField
    }()

    public var onTextChange: (String?) -> Void = {(_) in }

    public var showValidator: Bool = false {
        didSet {
            validView.hidden = !showValidator
        }
    }

    public lazy var validView: ValidatorView = {
        let validView = ValidatorView(frame: CGRectZero)
        self.contentView.addSubview(validView)

        validView.translatesAutoresizingMaskIntoConstraints = false
        validView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Left)
        validView.autoPinEdge(.Left, toEdge: .Right, ofView: self.textField)
        return validView
    }()

    public var isValid: Bool {
        return validView.state == .Valid
    }

    public func setValid(valid: Bool) {
        validView.endValidating(valid)
    }

    // MARK: UITextFieldDelegate

    public func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange,
        replacementString string: String) -> Bool {
            guard let text = textField.text else { return true }
            let changedText = (text as NSString).stringByReplacingCharactersInRange(range, withString: string)

            if showValidator {
                validView.beginValidating()
            }
            onTextChange(changedText)

            return true
    }
}
