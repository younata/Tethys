import UIKit

public final class TextFieldCell: UITableViewCell {
    public lazy var textField: UITextField = {
        let textField = UITextField(forAutoLayout: ())
        textField.delegate = self
        textField.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)

        return textField
    }()

    public var onTextChange: ((String?) -> Void)? = nil

    public var showValidator: Bool = false {
        didSet {
            self.validView.isHidden = !self.showValidator
        }
    }

    public var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    public lazy var validView: ValidatorView = {
        let validView = ValidatorView(frame: CGRect.zero)
        validView.translatesAutoresizingMaskIntoConstraints = false
        return validView
    }()

    public var isValid: Bool { return self.validView.state == .valid }

    public func setValid(_ valid: Bool) {
        self.validView.endValidating(valid)
    }

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(self.textField)
        self.textField.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0),
            excludingEdge: .trailing)

        self.contentView.addSubview(self.validView)
        self.validView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .leading)
        self.validView.autoPinEdge(.leading, to: .trailing, of: self.textField)

        self.selectionStyle = .none
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("nope") }
}

extension TextFieldCell: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.textField.textColor = self.themeRepository?.textColor
        self.backgroundColor = self.themeRepository?.backgroundColor
    }
}

extension TextFieldCell: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
        replacementString string: String) -> Bool {
            guard let text = textField.text else { return true }
            let changedText = (text as NSString).replacingCharacters(in: range, with: string)

            if self.showValidator {
                self.validView.beginValidating()
            }
            self.onTextChange?(changedText)

            return true
    }
}
