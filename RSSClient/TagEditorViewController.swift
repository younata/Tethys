import UIKit
import Ra
import rNewsKit

public class TagEditorViewController: UIViewController, Injectable {

    public var feed: Feed? = nil
    public var tagIndex: Int? = nil
    public let tagPicker = TagPickerView(frame: CGRectZero)

    private let tagLabel = UILabel(forAutoLayout: ())
    private var tag: String? = nil {
        didSet {
            self.navigationItem.rightBarButtonItem?.enabled = self.feed != nil && self.tag != nil
        }
    }
    private let feedRepository: FeedRepository
    private let themeRepository: ThemeRepository

    public init(feedRepository: FeedRepository, themeRepository: ThemeRepository) {
        self.feedRepository = feedRepository
        self.themeRepository = themeRepository
        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            feedRepository: injector.create(FeedRepository)!,
            themeRepository: injector.create(ThemeRepository)!
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.edgesForExtendedLayout = .None

        let saveTitle = NSLocalizedString("Generic_Save", comment: "")
        let saveButton = UIBarButtonItem(title: saveTitle, style: .Plain, target: self, action: "save")
        self.navigationItem.rightBarButtonItem = saveButton
        self.navigationItem.rightBarButtonItem?.enabled = false
        self.navigationItem.title = self.feed?.displayTitle ?? ""

        self.tagPicker.translatesAutoresizingMaskIntoConstraints = false
        self.tagPicker.themeRepository = self.themeRepository
        self.feedRepository.allTags { tags in
            self.tagPicker.configureWithTags(tags) {
                self.tag = $0
            }
        }
        self.view.addSubview(self.tagPicker)
        self.tagPicker.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(16, 8, 0, 8), excludingEdge: .Bottom)

        self.view.addSubview(self.tagLabel)
        self.tagLabel.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        self.tagLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        self.tagLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: tagPicker, withOffset: 8)
        self.tagLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        self.tagLabel.numberOfLines = 0
        self.tagLabel.text = NSLocalizedString("TagEditorViewController_Explanation", comment: "")

        self.themeRepository.addSubscriber(self)
    }

    @objc private func dismiss() {
        self.navigationController?.popViewControllerAnimated(true)
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
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.view.backgroundColor = themeRepository.backgroundColor

        self.tagPicker.picker.tintColor = themeRepository.textColor
        self.tagPicker.textField.textColor = themeRepository.textColor

        self.tagLabel.textColor = themeRepository.textColor

        self.navigationController?.navigationBar.barTintColor = themeRepository.backgroundColor
    }
}
