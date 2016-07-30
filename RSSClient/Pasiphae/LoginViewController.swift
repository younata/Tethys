import UIKit
import PureLayout
import rNewsKit
import Ra
import CBGPromise
import Result

extension Account {
    public var titleText: String {
        switch self {
        case .Pasiphae:
            return NSLocalizedString("LoginViewController_Pasiphae_Title", comment: "")
        }
    }

    public var detailText: String {
        switch self {
        case .Pasiphae:
            return ""
        }
    }
}

@objc private class LoginTextFieldDelegate: NSObject, UITextFieldDelegate {
    private let textFields: [UITextField]
    private let onValidation: Bool -> Void

    private init(textFields: [UITextField], onValidation: Bool -> Void) {
        self.textFields = textFields
        self.onValidation = onValidation
    }

    @objc private func textField(textField: UITextField,
                                 shouldChangeCharactersInRange range: NSRange,
                                                               replacementString string: String) -> Bool {
        let string = NSString(string: textField.text ?? "").stringByReplacingCharactersInRange(range,
                                                                                               withString: string)
        let textFieldStrings: [String] = self.textFields.filter({ $0 != textField }).map({$0.text ?? ""}) + [string]

        let valid = textFieldStrings.reduce(true) { $0 && !$1.isEmpty }
        self.onValidation(valid)

        return true
    }
}

public class LoginViewController: UIViewController, Injectable {
    public var accountType: Account? {
        didSet {
            self.title = self.accountType?.description
            self.titleLabel.text = self.accountType?.titleText
            self.detailLabel.text = self.accountType?.detailText
        }
    }

    private lazy var textFieldDelegate: LoginTextFieldDelegate = {
        return LoginTextFieldDelegate(textFields: [self.emailField, self.passwordField]) { valid in
            self.loginButton.enabled = valid
            self.registerButton.enabled = valid
        }
    }()

    public let titleLabel: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.textAlignment = .Center
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        label.accessibilityLabel = NSLocalizedString("LoginViewController_Title_Accessibility_Label", comment: "")
        return label
    }()

    public let detailLabel: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.numberOfLines = 0
        label.textAlignment = .Center
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        label.accessibilityLabel = NSLocalizedString("LoginViewController_Detail_Accessibility_Label", comment: "")
        return label
    }()

    public let errorLabel: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.numberOfLines = 0
        label.textAlignment = .Center
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        label.accessibilityLabel = NSLocalizedString("LoginViewController_Error_Accessibility_Label", comment: "")
        return label
    }()

    public let emailField: UITextField = {
        let field = UITextField(forAutoLayout: ())
        field.autocapitalizationType = .None
        field.autocorrectionType = .No
        field.placeholder = NSLocalizedString("LoginViewController_Fields_Email", comment: "")
        field.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        field.accessibilityLabel = NSLocalizedString("LoginViewController_Fields_Email", comment: "")
        field.accessibilityHint = NSLocalizedString("LoginViewController_Fields_Email_Accessibility_Hint", comment: "")
        return field
    }()

    public let passwordField: UITextField = {
        let field = UITextField(forAutoLayout: ())
        field.secureTextEntry = true
        field.placeholder = NSLocalizedString("LoginViewController_Fields_Password", comment: "")
        field.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        field.accessibilityLabel = NSLocalizedString("LoginViewController_Fields_Password", comment: "")
        field.accessibilityHint = NSLocalizedString("LoginViewController_Fields_Password_Accessibility_Hint", comment: "")
        return field
    }()

    public let loginButton: UIButton = {
        let button = UIButton(type: .System)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.enabled = false
        button.setTitleColor(UIColor.darkGreenColor(), forState: .Normal)
        button.setTitle(NSLocalizedString("LoginViewController_Fields_Login", comment: ""), forState: .Normal)
        button.titleLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        button.accessibilityLabel = NSLocalizedString("LoginViewController_Fields_Login", comment: "")
        button.accessibilityHint = NSLocalizedString("LoginViewController_Fields_Login_Accessibility_Hint", comment: "")
        return button
    }()

    public let registerButton: UIButton = {
        let button = UIButton(type: .System)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.enabled = false
        button.setTitleColor(UIColor.darkGreenColor(), forState: .Normal)
        button.setTitle(NSLocalizedString("LoginViewController_Fields_Register", comment: ""), forState: .Normal)
        button.titleLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        button.accessibilityLabel = NSLocalizedString("LoginViewController_Fields_Register", comment: "")
        button.accessibilityHint = NSLocalizedString("LoginViewController_Fields_Register_Accessibility_Hint",
                                                     comment: "")
        return button
    }()

    private let accountRepository: AccountRepository
    private let mainQueue: NSOperationQueue

    public init(themeRepository: ThemeRepository, accountRepository: AccountRepository, mainQueue: NSOperationQueue) {
        self.accountRepository = accountRepository
        self.mainQueue = mainQueue

        super.init(nibName: nil, bundle: nil)
        themeRepository.addSubscriber(self)
    }

    public convenience required init(injector: Injector) {
        self.init(
            themeRepository: injector.create(ThemeRepository)!,
            accountRepository: injector.create(AccountRepository)!,
            mainQueue: injector.create(kMainQueue) as! NSOperationQueue
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
        mainStackView.axis = .Vertical
        mainStackView.spacing = 10
        mainStackView.distribution = .EqualCentering
        mainStackView.alignment = .Center

        mainStackView.addArrangedSubview(self.titleLabel)
        mainStackView.addArrangedSubview(self.detailLabel)
        mainStackView.addArrangedSubview(self.emailField)
        mainStackView.addArrangedSubview(self.passwordField)
        mainStackView.addArrangedSubview(self.errorLabel)

        let buttonStack = UIStackView(arrangedSubviews: [self.registerButton, self.loginButton])
        buttonStack.axis = .Horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .FirstBaseline
        buttonStack.distribution = .EqualCentering
        buttonStack.spacing = 20
        mainStackView.addArrangedSubview(buttonStack)

        self.view.addSubview(mainStackView)
        mainStackView.autoAlignAxisToSuperviewAxis(.Horizontal)
        mainStackView.autoPinEdgeToSuperviewMargin(.Leading)
        mainStackView.autoPinEdgeToSuperviewMargin(.Trailing)

        self.emailField.autoPinEdgeToSuperviewEdge(.Leading, withInset: 40)
        self.emailField.autoPinEdgeToSuperviewEdge(.Trailing, withInset: 40)
        self.passwordField.autoPinEdgeToSuperviewEdge(.Leading, withInset: 40)
        self.passwordField.autoPinEdgeToSuperviewEdge(.Trailing, withInset: 40)

        self.loginButton.addTarget(self,
                                      action: #selector(LoginViewController.login),
                                      forControlEvents: .TouchUpInside)
        self.registerButton.addTarget(self,
                                      action: #selector(LoginViewController.register),
                                      forControlEvents: .TouchUpInside)

        self.view.backgroundColor = UIColor.whiteColor()
    }

    @objc private func login() {
        let message = NSLocalizedString("LoginViewController_Login_Message", comment: "")
        self.sendLoginOrRegisterRequest(message, requestMaker: self.accountRepository.login)
    }

    @objc private func register() {
        let message = NSLocalizedString("LoginViewController_Register_Message", comment: "")
        self.sendLoginOrRegisterRequest(message, requestMaker: self.accountRepository.register)
    }

    private func sendLoginOrRegisterRequest(message: String, requestMaker: (String, String) ->
        Future<Result<Void, RNewsError>>) {
        let activityIndicator = self.disableInteractionWithMessage(message)
        requestMaker(self.emailField.text ?? "", self.passwordField.text ?? "").then { res in
            self.mainQueue.addOperationWithBlock {
                activityIndicator.removeFromSuperview()
                switch res {
                case .Success():
                    self.navigationController?.popViewControllerAnimated(false)
                case let .Failure(error):
                    self.errorLabel.text = error.description
                }
            }
        }
    }

    private func disableInteractionWithMessage(message: String) -> ActivityIndicator {
        let activityIndicator = ActivityIndicator(forAutoLayout: ())
        activityIndicator.configureWithMessage(message)
        let color = activityIndicator.backgroundColor
        activityIndicator.backgroundColor = UIColor.clearColor()

        self.view.addSubview(activityIndicator)
        activityIndicator.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        UIView.animateWithDuration(0.3) {
            activityIndicator.backgroundColor = color
        }
        return activityIndicator
    }
}

extension LoginViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.view.backgroundColor = themeRepository.backgroundColor
        self.titleLabel.textColor = themeRepository.textColor
        self.detailLabel.textColor = themeRepository.textColor
        self.errorLabel.textColor = themeRepository.errorColor
    }
}
