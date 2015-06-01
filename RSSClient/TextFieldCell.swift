import UIKit

public class TextFieldCell: UITableViewCell, UITextFieldDelegate {

    public let textField = UITextField(forAutoLayout: ())

    var onTextChange: (String?) -> Void = {(_) in }

    var showValidator: Bool = false {
        didSet {
            validView.hidden = !showValidator
        }
    }
    var validate: (String) -> Bool = {(_) in return false}

    let validView = ValidatorView(frame: CGRectZero)

    public var isValid: Bool {
        return validView.state == .Valid
    }

    func setValid(valid: Bool) {
        validView.endValidating(valid: valid)
    }

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(textField)
        textField.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Right)
        textField.delegate = self
        textField.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)

        self.contentView.addSubview(validView)
        validView.setTranslatesAutoresizingMaskIntoConstraints(false)
        validView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Left)
        validView.autoPinEdge(.Left, toEdge: .Right, ofView: textField)

        showValidator = false
    }

    public required init(coder: NSCoder) {
        fatalError("")
    }

    // MARK: UITextFieldDelegate

    public func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange,
        replacementString string: String) -> Bool {
            let text = (textField.text as NSString).stringByReplacingCharactersInRange(range, withString: string)

            if showValidator {
                validView.beginValidating()
            }
            onTextChange(text)

            return true
    }
}
