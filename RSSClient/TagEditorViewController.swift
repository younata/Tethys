import UIKit

public class TagEditorViewController: UIViewController {

    public var feed: Feed? = nil
    var tag: String? = nil {
        didSet {
            self.navigationItem.rightBarButtonItem?.enabled = self.feed != nil && tag != nil
        }
    }

    public var tagIndex: Int? = nil
    let tagLabel = UILabel(forAutoLayout: ())
    let tagPicker = TagPickerView(frame: CGRectZero)

    lazy var dataManager: DataManager = {
        self.injector!.create(DataManager.self) as! DataManager
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.edgesForExtendedLayout = .None

        let saveTitle = NSLocalizedString("Save", comment: "")
        let saveButton = UIBarButtonItem(title: saveTitle, style: .Plain, target: self, action: "save")
        self.navigationItem.rightBarButtonItem = saveButton
        self.navigationItem.rightBarButtonItem?.enabled = false
        self.navigationItem.title = self.feed?.title ?? ""

        tagPicker.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.view.addSubview(tagPicker)
        tagPicker.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(16, 8, 0, 8), excludingEdge: .Bottom)
        tagPicker.allTags = dataManager.allTags()
        tagPicker.didSelect = {
            self.tag = $0
        }

        self.view.addSubview(tagLabel)
        tagLabel.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        tagLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        tagLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: tagPicker, withOffset: 8)
        tagLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        tagLabel.numberOfLines = 0
        tagLabel.text = NSLocalizedString("Prefixing a tag with '~' will set the title to that, minus the leading ~. Prefixing a tag with '`' will set the summary to that, minus the leading `. Tags cannot contain commas (,)", comment: "")
    }

    func dismiss() {
        self.navigationController?.popViewControllerAnimated(true)
    }

    func save() {
        if var feed = self.feed, let tag = tag {
            feed.addTag(tag)
            self.feed = feed
        }

        self.dismiss()
    }
}
