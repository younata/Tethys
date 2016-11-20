import UIKit
import Ra
import rNewsKit

public class GenerateBookViewController: UIViewController, Injectable {
    public weak var articles: DataStoreBackedArray<Article>?

    public let titleField: UITextField = {
        let field = UITextField(forAutoLayout: ())
        field.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
        let placeholder = NSAttributedString(string:
            NSLocalizedString("GenerateBookViewController_titlefield_placeholder", comment: ""),
                                             attributes: [NSForegroundColorAttributeName: UIColor.gray])
        field.attributedPlaceholder = placeholder
        field.accessibilityHint = NSLocalizedString("GenerateBookViewController_titlefield_Accessibility_Hint",
                                                    comment: "")
        return field
    }()

    public let authorField: UITextField = {
        let field = UITextField(forAutoLayout: ())
        field.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
        let placeholder = NSAttributedString(string:
            NSLocalizedString("GenerateBookViewController_authorfield_placeholder", comment: ""),
                                             attributes: [NSForegroundColorAttributeName: UIColor.gray])
        field.attributedPlaceholder = placeholder
        field.accessibilityHint = NSLocalizedString("GenerateBookViewController_authorfield_Accessibility_Hint",
                                                    comment: "")
        return field
    }()

    public let formatSelector: UISegmentedControl = {
        let control = UISegmentedControl(items: [
            NSLocalizedString("GenerateBookViewController_Formats_ePub", comment: ""),
            NSLocalizedString("GenerateBookViewController_Formats_Kindle", comment: ""),
        ])
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0
        control.tintColor = UIColor.darkGreen()
        control.accessibilityHint = NSLocalizedString("GenerateBookViewController_Formats_Accessibility_Hint",
                                                      comment: "")
        return control
    }()


    public let generateButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        button.setTitleColor(UIColor.darkGreen(), for: .normal)
        button.setTitleColor(UIColor.gray, for: .disabled)
        button.setTitle(NSLocalizedString("GenerateBookViewController_Create", comment: ""), for: UIControlState())
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
//        button.accessibilityLabel = NSLocalizedString("LoginViewController_Fields_Login", comment: "")
//        button.accessibilityHint = NSLocalizedString("LoginViewController_Fields_Login_Accessibility_Hint", comment: "")
        return button
    }()

    private let themeRepository: ThemeRepository
    public let chapterOrganizer: ChapterOrganizerController

    public init(themeRepository: ThemeRepository, chapterOrganizer: ChapterOrganizerController) {
        self.themeRepository = themeRepository
        self.chapterOrganizer = chapterOrganizer
        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            chapterOrganizer: injector.create(kind: ChapterOrganizerController.self)!
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.addChildViewController(self.chapterOrganizer)

        self.themeRepository.addSubscriber(self)

        self.title = NSLocalizedString("GenerateBookViewController_Title", comment: "")

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Generic_Dismiss", comment: ""),
            style: .plain,
            target: self,
            action: #selector(GenerateBookViewController.dismissController)
        )

        let mainStackView = UIStackView(forAutoLayout: ())
        mainStackView.axis = .vertical
        mainStackView.spacing = 10
        mainStackView.distribution = .equalSpacing
        mainStackView.alignment = .center

        mainStackView.addArrangedSubview(self.titleField)
        mainStackView.addArrangedSubview(self.authorField)
        mainStackView.addArrangedSubview(self.formatSelector)
        mainStackView.addArrangedSubview(self.chapterOrganizer.view)
        mainStackView.addArrangedSubview(self.generateButton)

        self.view.addSubview(mainStackView)
        mainStackView.autoAlignAxis(toSuperviewAxis: .horizontal)
        mainStackView.autoPinEdge(toSuperviewEdge: .leading)
        mainStackView.autoPinEdge(toSuperviewEdge: .trailing)

        self.titleField.autoPinEdge(toSuperviewEdge: .leading, withInset: 40)
        self.authorField.autoPinEdge(toSuperviewEdge: .leading, withInset: 40)
        self.formatSelector.autoPinEdge(toSuperviewEdge: .leading, withInset: 40)
        self.titleField.autoPinEdge(toSuperviewEdge: .trailing, withInset: 40)
        self.authorField.autoPinEdge(toSuperviewEdge: .trailing, withInset: 40)
        self.formatSelector.autoPinEdge(toSuperviewEdge: .trailing, withInset: 40)

        self.chapterOrganizer.view.autoPinEdge(toSuperviewEdge: .leading, withInset: 40)
        self.chapterOrganizer.view.autoPinEdge(toSuperviewEdge: .trailing, withInset: 40)
    }

    @objc private func dismissController() {
        self.navigationController?.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}

extension GenerateBookViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSForegroundColorAttributeName: themeRepository.textColor
        ]

        self.view.backgroundColor = themeRepository.backgroundColor

        self.titleField.textColor = themeRepository.textColor
        self.authorField.textColor = themeRepository.textColor

        self.formatSelector.setTitleTextAttributes([NSForegroundColorAttributeName: themeRepository.textColor],
                                                   for: .normal)
        self.formatSelector.setTitleTextAttributes([NSForegroundColorAttributeName: themeRepository.backgroundColor],
                                                   for: .selected)
    }
}
