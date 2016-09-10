import UIKit
import PureLayout
import rNewsKit
import Ra
import CBGPromise
import Result

extension Account {
    public var titleText: String {
        switch self {
        case .pasiphae:
            return NSLocalizedString("LoginViewController_Pasiphae_Title", comment: "")
        }
    }

    public var detailText: String {
        switch self {
        case .pasiphae:
            return ""
        }
    }
}

@objc private class LoginTextFieldDelegate: NSObject, UITextFieldDelegate {
    fileprivate let textFields: [UITextField]
    fileprivate let onValidation: (Bool) -> Void

    fileprivate init(textFields: [UITextField], onValidation: @escaping (Bool) -> Void) {
        self.textFields = textFields
        self.onValidation = onValidation
    }

    @objc fileprivate func textField(_ textField: UITextField,
                                 shouldChangeCharactersIn range: NSRange,
                                                               replacementString string: String) -> Bool {
        let string = NSString(string: textField.text ?? "").replacingCharacters(in: range,
                                                                                               with: string)
        let textFieldStrings: [String] = self.textFields.filter({ $0 != textField }).map({$0.text ?? ""}) + [string]

        let valid = textFieldStrings.reduce(true) { $0 && !$1.isEmpty }
        self.onValidation(valid)

        return true
    }
}

public final class LoginViewController: UIViewController, Injectable {
    public var accountType: Account? {
        didSet {
            self.title = self.accountType?.description
            self.titleLabel.text = self.accountType?.titleText
            self.detailLabel.text = self.accountType?.detailText
        }
    }

    private lazy var textFieldDelegate: LoginTextFieldDelegate = {
        return LoginTextFieldDelegate(textFields: [self.emailField, self.passwordField]) { valid in
            self.loginButton.isEnabled = valid
            self.registerButton.isEnabled = valid
        }
    }()

    public let titleLabel: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
        label.accessibilityLabel = NSLocalizedString("LoginViewController_Title_Accessibility_Label", comment: "")
        return label
    }()

    public let detailLabel: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        label.accessibilityLabel = NSLocalizedString("LoginViewController_Detail_Accessibility_Label", comment: "")
        return label
    }()

    public let errorLabel: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        label.accessibilityLabel = NSLocalizedString("LoginViewController_Error_Accessibility_Label", comment: "")
        return label
    }()

    public let emailField: UITextField = {
        let field = UITextField(forAutoLayout: ())
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        let placeholder = NSAttributedString(string: NSLocalizedString("LoginViewController_Fields_Email", comment: ""),
                                             attributes: [NSForegroundColorAttributeName: UIColor.gray])
        field.attributedPlaceholder = placeholder
        field.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
        field.accessibilityLabel = NSLocalizedString("LoginViewController_Fields_Email", comment: "")
        field.accessibilityHint = NSLocalizedString("LoginViewController_Fields_Email_Accessibility_Hint", comment: "")
        return field
    }()

    public let passwordField: UITextField = {
        let field = UITextField(forAutoLayout: ())
        field.isSecureTextEntry = true
        let placeholder = NSAttributedString(string: NSLocalizedString("LoginViewController_Fields_Password",
                                                                       comment: ""),
                                             attributes: [NSForegroundColorAttributeName: UIColor.gray])
        field.attributedPlaceholder = placeholder
        field.placeholder = NSLocalizedString("LoginViewController_Fields_Password", comment: "")
        field.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
        field.accessibilityLabel = NSLocalizedString("LoginViewController_Fields_Password", comment: "")
        field.accessibilityHint = NSLocalizedString("LoginViewController_Fields_Password_Accessibility_Hint",
                                                    comment: "")
        return field
    }()

    public let loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        button.setTitleColor(UIColor.darkGreen(), for: UIControlState())
        button.setTitle(NSLocalizedString("LoginViewController_Fields_Login", comment: ""), for: UIControlState())
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
        button.accessibilityLabel = NSLocalizedString("LoginViewController_Fields_Login", comment: "")
        button.accessibilityHint = NSLocalizedString("LoginViewController_Fields_Login_Accessibility_Hint", comment: "")
        return button
    }()

    public let registerButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        button.setTitleColor(UIColor.darkGreen(), for: UIControlState())
        button.setTitle(NSLocalizedString("LoginViewController_Fields_Register", comment: ""), for: UIControlState())
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
        button.accessibilityLabel = NSLocalizedString("LoginViewController_Fields_Register", comment: "")
        button.accessibilityHint = NSLocalizedString("LoginViewController_Fields_Register_Accessibility_Hint",
                                                     comment: "")
        return button
    }()

    private let accountRepository: AccountRepository
    private let mainQueue: OperationQueue

    public init(themeRepository: ThemeRepository, accountRepository: AccountRepository, mainQueue: OperationQueue) {
        self.accountRepository = accountRepository
        self.mainQueue = mainQueue

        super.init(nibName: nil, bundle: nil)
        themeRepository.addSubscriber(self)
    }

    public convenience required init(injector: Injector) {
        self.init(
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            accountRepository: injector.create(kind: AccountRepository.self)!,
            mainQueue: injector.create(string: kMainQueue) as! OperationQueue
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.emailField.delegate = self.textFieldDelegate
        self.passwordField.delegate = self.textFieldDelegate

        let mainStackView = UIStackView(forAutoLayout: ())
        mainStackView.axis = .vertical
        mainStackView.spacing = 10
        mainStackView.distribution = .equalCentering
        mainStackView.alignment = .center

        mainStackView.addArrangedSubview(self.titleLabel)
        mainStackView.addArrangedSubview(self.detailLabel)
        mainStackView.addArrangedSubview(self.emailField)
        mainStackView.addArrangedSubview(self.passwordField)
        mainStackView.addArrangedSubview(self.errorLabel)

        let buttonStack = UIStackView(arrangedSubviews: [self.registerButton, self.loginButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .firstBaseline
        buttonStack.distribution = .equalCentering
        buttonStack.spacing = 20
        mainStackView.addArrangedSubview(buttonStack)

        self.view.addSubview(mainStackView)
        mainStackView.autoAlignAxis(toSuperviewAxis: .horizontal)
        mainStackView.autoPinEdge(toSuperviewMargin: .leading)
        mainStackView.autoPinEdge(toSuperviewMargin: .trailing)

        self.emailField.autoPinEdge(toSuperviewEdge: .leading, withInset: 40)
        self.emailField.autoPinEdge(toSuperviewEdge: .trailing, withInset: 40)
        self.passwordField.autoPinEdge(toSuperviewEdge: .leading, withInset: 40)
        self.passwordField.autoPinEdge(toSuperviewEdge: .trailing, withInset: 40)

        self.loginButton.addTarget(self,
                                      action: #selector(LoginViewController.login),
                                      for: .touchUpInside)
        self.registerButton.addTarget(self,
                                      action: #selector(LoginViewController.register),
                                      for: .touchUpInside)

        self.view.backgroundColor = UIColor.white
    }

    @objc private func login() {
        let message = NSLocalizedString("LoginViewController_Login_Message", comment: "")
        self.sendLoginOrRegisterRequest(message, requestMaker: self.accountRepository.login)
    }

    @objc private func register() {
        let message = NSLocalizedString("LoginViewController_Register_Message", comment: "")
        self.sendLoginOrRegisterRequest(message, requestMaker: self.accountRepository.register)
    }

    private func sendLoginOrRegisterRequest(_ message: String, requestMaker: (String, String) ->
        Future<Result<Void, RNewsError>>) {
        let activityIndicator = self.disableInteractionWithMessage(message)
        _ = requestMaker(self.emailField.text ?? "", self.passwordField.text ?? "").then { res in
            self.mainQueue.addOperation {
                activityIndicator.removeFromSuperview()
                switch res {
                case .success():
                    _ = self.navigationController?.popViewController(animated: false)
                case let .failure(error):
                    self.errorLabel.text = error.description
                }
            }
        }
    }

    private func disableInteractionWithMessage(_ message: String) -> ActivityIndicator {
        let activityIndicator = ActivityIndicator(forAutoLayout: ())
        activityIndicator.configure(message: message)
        let color = activityIndicator.backgroundColor
        activityIndicator.backgroundColor = UIColor.clear

        self.view.addSubview(activityIndicator)
        activityIndicator.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)

        UIView.animate(withDuration: 0.3) {
            activityIndicator.backgroundColor = color
        }
        return activityIndicator
    }
}

extension LoginViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.view.backgroundColor = themeRepository.backgroundColor
        self.titleLabel.textColor = themeRepository.textColor
        self.detailLabel.textColor = themeRepository.textColor
        self.errorLabel.textColor = themeRepository.errorColor

        self.emailField.textColor = themeRepository.textColor
        self.passwordField.textColor = themeRepository.textColor
    }
}
