import UIKit
import Ra
import rNewsKit
import CBGPromise
import Result
import Sponde

public class GenerateBookViewController: UIViewController, Injectable {
    public weak var articles: DataStoreBackedArray<Article>? {
        didSet {
            self.chapterOrganizer.articles = articles
        }
    }

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
        return button
    }()

    fileprivate var bookTitle: String = "" { didSet { self.validateBook() } }
    fileprivate var bookAuthor: String = "" { didSet { self.validateBook() } }
    fileprivate var bookChapters: [Article] = [] { didSet { self.validateBook() } }

    private let themeRepository: ThemeRepository
    private let generateBookUseCase: GenerateBookUseCase
    public let chapterOrganizer: ChapterOrganizerController

    public init(themeRepository: ThemeRepository,
                generateBookUseCase: GenerateBookUseCase,
                chapterOrganizer: ChapterOrganizerController) {
        self.themeRepository = themeRepository
        self.chapterOrganizer = chapterOrganizer
        self.generateBookUseCase = generateBookUseCase
        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            generateBookUseCase: injector.create(kind: GenerateBookUseCase.self)!,
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

        let dismissKeyboardRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(GenerateBookViewController.dismissKeyboard)
        )
        self.view.addGestureRecognizer(dismissKeyboardRecognizer)

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

        self.titleField.delegate = self
        self.authorField.delegate = self
        self.chapterOrganizer.delegate = self
        self.generateButton.addTarget(self,
                                      action: #selector(GenerateBookViewController.generateBook),
                                      for: .touchUpInside)

        mainStackView.addArrangedSubview(self.titleField)
        mainStackView.addArrangedSubview(self.authorField)
        mainStackView.addArrangedSubview(self.formatSelector)
        mainStackView.addArrangedSubview(self.chapterOrganizer.view)
        mainStackView.addArrangedSubview(self.generateButton)

        self.view.addSubview(mainStackView)
        mainStackView.autoPinEdge(toSuperviewEdge: .leading)
        mainStackView.autoPinEdge(toSuperviewEdge: .trailing)
        mainStackView.autoPinEdge(toSuperviewEdge: .top, withInset: 84)
        mainStackView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 20, relation: .greaterThanOrEqual)

        self.titleField.autoPinEdge(toSuperviewEdge: .leading, withInset: 40)
        self.authorField.autoPinEdge(toSuperviewEdge: .leading, withInset: 40)
        self.formatSelector.autoPinEdge(toSuperviewEdge: .leading, withInset: 40)
        self.titleField.autoPinEdge(toSuperviewEdge: .trailing, withInset: 40)
        self.authorField.autoPinEdge(toSuperviewEdge: .trailing, withInset: 40)
        self.formatSelector.autoPinEdge(toSuperviewEdge: .trailing, withInset: 40)

        self.chapterOrganizer.view.autoPinEdge(toSuperviewEdge: .leading)
        self.chapterOrganizer.view.autoPinEdge(toSuperviewEdge: .trailing)

        self.setChapterMaxHeight(height: self.view.bounds.size.height)
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        self.setChapterMaxHeight(height: size.height)
    }

    private func setChapterMaxHeight(height: CGFloat) {
        self.chapterOrganizer.maxHeight = Int(height - 300)
    }

    @objc private func dismissKeyboard() {
        self.titleField.resignFirstResponder()
        self.authorField.resignFirstResponder()
    }

    @objc private func dismissController() {
        self.navigationController?.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @objc private func generateBook() {
        let indicator = ActivityIndicator(forAutoLayout: ())
        self.view.addSubview(indicator)
        indicator.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)

        indicator.configure(message: NSLocalizedString("GenerateBookViewController_Generating_Message", comment: ""))

        let format: Book.Format

        switch self.formatSelector.selectedSegmentIndex {
        case 0:
            format = .epub
        case 1:
            format = .mobi
        default:
            fatalError("Unknown Format")
        }

        let future = self.generateBookUseCase.generateBook(title: self.bookTitle,
                                                           author: self.bookAuthor,
                                                           chapters: self.bookChapters,
                                                           format: format)
        _ = future.then { result in
            indicator.removeFromSuperview()
            let viewController: UIViewController
            switch result {
            case let .success(url):
                viewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            case let .failure(error):
                let alertTitle = NSLocalizedString("GenerateBookViewController_Generating_Error_Title", comment: "")
                let alert = UIAlertController(title: alertTitle,
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("Generic_Ok", comment: ""),
                                              style: .default) { _ in
                                                self.dismiss(animated: true, completion: nil)
                })
                viewController = alert
            }
            self.present(viewController, animated: true, completion: nil)
        }
    }

    private func validateBook() {
        if self.bookTitle.isEmpty || self.bookAuthor.isEmpty || self.bookChapters.isEmpty {
            self.generateButton.isEnabled = false
        } else {
            self.generateButton.isEnabled = true
        }
    }
}

extension GenerateBookViewController: UITextFieldDelegate {
    public func textField(_ textField: UITextField,
                          shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool {
        let text = NSString(string: textField.text ?? "").replacingCharacters(in: range, with: string)
        if textField == self.authorField {
            self.bookAuthor = text
        } else if textField == self.titleField {
            self.bookTitle = text
        }
        return true
    }
}

extension GenerateBookViewController: ChapterOrganizerControllerDelegate {
    public func chapterOrganizerControllerDidChangeChapters(_ chapterOrganizer: ChapterOrganizerController) {
        self.bookChapters = chapterOrganizer.chapters
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
