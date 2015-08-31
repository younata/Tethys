import UIKit

public class TextFieldCell: UITableViewCell {

    public lazy var textField: UITextField = {
        let textField = UITextField(forAutoLayout: ())
        textField.delegate = self
        textField.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)

        return textField
    }()

    public var onTextChange: (String?) -> Void = {(_) in }

    public var showValidator: Bool = false {
        didSet {
            self.validView.hidden = !self.showValidator
        }
    }

    public var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    public lazy var validView: ValidatorView = {
        let validView = ValidatorView(frame: CGRectZero)
        validView.translatesAutoresizingMaskIntoConstraints = false
        return validView
    }()

    public var isValid: Bool {
        return self.validView.state == .Valid
    }

    public func setValid(valid: Bool) {
        self.validView.endValidating(valid)
    }

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(self.textField)
        self.textField.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0), excludingEdge: .Trailing)

        self.contentView.addSubview(self.validView)
        self.validView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Leading)
        self.validView.autoPinEdge(.Leading, toEdge: .Trailing, ofView: self.textField)

        self.selectionStyle = .None
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("nope")
    }
}

extension TextFieldCell: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.textField.textColor = self.themeRepository?.textColor
        self.backgroundColor = self.themeRepository?.backgroundColor
    }
}

extension TextFieldCell: UITextFieldDelegate {
    public func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange,
        replacementString string: String) -> Bool {
            guard let text = textField.text else { return true }
            let changedText = (text as NSString).stringByReplacingCharactersInRange(range, withString: string)

            if self.showValidator {
                self.validView.beginValidating()
            }
            self.onTextChange(changedText)

            return true
    }
}
