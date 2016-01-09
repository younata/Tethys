import UIKit
import rNewsKit

public class TagEditorViewController: UIViewController {

    public var feed: Feed? = nil
    public var tagIndex: Int? = nil
    public let tagPicker = TagPickerView(frame: CGRectZero)

    private let tagLabel = UILabel(forAutoLayout: ())
    private var tag: String? = nil {
        didSet {
            self.navigationItem.rightBarButtonItem?.enabled = self.feed != nil && self.tag != nil
        }
    }
    private lazy var dataWriter: DataWriter? = {
        self.injector?.create(DataWriter)
    }()

    private lazy var dataRetriever: DataRetriever? = {
        self.injector?.create(DataRetriever)
    }()

    private lazy var themeRepository: ThemeRepository? = {
        self.injector?.create(ThemeRepository)
    }()

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
        self.dataRetriever?.allTags { tags in
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

        self.themeRepository?.addSubscriber(self)
    }

    @objc private func dismiss() {
        self.navigationController?.popViewControllerAnimated(true)
    }

    @objc private func save() {
        if let feed = self.feed, let tag = tag {
            feed.addTag(tag)
            self.dataWriter?.saveFeed(feed)
            self.feed = feed
        }

        self.dismiss()
    }
}

extension TagEditorViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.view.backgroundColor = self.themeRepository?.backgroundColor

        self.tagPicker.picker.tintColor = self.themeRepository?.textColor
        self.tagPicker.textField.textColor = self.themeRepository?.textColor

        self.tagLabel.textColor = self.themeRepository?.textColor

        self.navigationController?.navigationBar.barTintColor = self.themeRepository?.backgroundColor
    }
}
