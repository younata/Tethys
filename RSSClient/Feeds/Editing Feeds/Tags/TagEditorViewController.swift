import UIKit
import Ra
import Result
import rNewsKit

public final class TagEditorViewController: UIViewController, Injectable {

    public var feed: Feed? = nil
    public var tagIndex: Int? = nil
    public let tagPicker = TagPickerView(frame: CGRect.zero)

    fileprivate let tagLabel = UILabel(forAutoLayout: ())
    private var tag: String? = nil {
        didSet {
            self.navigationItem.rightBarButtonItem?.enabled = self.feed != nil && self.tag != nil
        }
    }
    private let feedRepository: DatabaseUseCase
    private let themeRepository: ThemeRepository

    public init(feedRepository: DatabaseUseCase, themeRepository: ThemeRepository) {
        self.feedRepository = feedRepository
        self.themeRepository = themeRepository
        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            feedRepository: injector.create(DatabaseUseCase)!,
            themeRepository: injector.create(ThemeRepository)!
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.edgesForExtendedLayout = UIRectEdge()

        let saveTitle = NSLocalizedString("Generic_Save", comment: "")
        let saveButton = UIBarButtonItem(title: saveTitle, style: .plain, target: self,
                                         action: #selector(TagEditorViewController.save))
        self.navigationItem.rightBarButtonItem = saveButton
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        self.navigationItem.title = self.feed?.displayTitle ?? ""

        self.tagPicker.translatesAutoresizingMaskIntoConstraints = false
        self.tagPicker.themeRepository = self.themeRepository
        self.feedRepository.allTags().then {
            if case let Result.success(tags) = $0 {
                self.tagPicker.configureWithTags(tags) {
                    self.tag = $0
                }
            }
        }
        self.view.addSubview(self.tagPicker)
        self.tagPicker.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16, left: 8, bottom: 0, right: 8),
                                                              excludingEdge: .bottom)

        self.view.addSubview(self.tagLabel)
        self.tagLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        self.tagLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 8)
        self.tagLabel.autoPinEdge(.top, to: .bottom, of: tagPicker, withOffset: 8)
        self.tagLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        self.tagLabel.numberOfLines = 0
        self.tagLabel.text = NSLocalizedString("TagEditorViewController_Explanation", comment: "")

        self.themeRepository.addSubscriber(self)
    }

    @objc private func dismiss() {
        self.navigationController?.popViewController(animated: true)
    }

    @objc private func save() {
        if let feed = self.feed, let tag = tag {
            feed.addTag(tag)
            self.feedRepository.saveFeed(feed)
            self.feed = feed
        }

        self.dismiss()
    }
}

extension TagEditorViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.view.backgroundColor = themeRepository.backgroundColor

        self.tagPicker.picker.tintColor = themeRepository.textColor
        self.tagPicker.textField.textColor = themeRepository.textColor

        self.tagLabel.textColor = themeRepository.textColor

        self.navigationController?.navigationBar.barTintColor = themeRepository.backgroundColor
    }
}
