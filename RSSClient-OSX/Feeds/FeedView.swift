import Cocoa
import rNewsKit

public protocol FeedViewDelegate {
    func didClickFeed(_ feed: Feed)
    func menuOptionsForFeed(_ feed: Feed) -> [String]
    func didSelectMenuOption(_ menuOption: String, forFeed: Feed)

}

public final class FeedView: NSView {
    public private(set) var feed: Feed? = nil {
        didSet {
            if let f = feed {
                self.nameLabel.string = f.displayTitle
                let font: NSFont = nameLabel.font!
                self.nameHeight?.constant = ceil(NSAttributedString(string: nameLabel.string!,
                    attributes: [NSFontAttributeName: font]).size().height)
                self.summaryLabel.string = f.displaySummary
                self.unreadCounter.unread = UInt(f.articlesArray.filter({return $0.read == false}).count)
                self.imageView.image = f.image
            } else {
                self.nameLabel.string = ""
                self.summaryLabel.string = ""
                self.unreadCounter.unread = 0
            }
        }
    }

    public private(set) var delegate: FeedViewDelegate? = nil

    public func configure(_ feed: Feed, delegate: FeedViewDelegate) {
        self.feed = feed
        self.delegate = delegate
    }

    public let nameLabel = NSTextView(forAutoLayout: ())
    public let summaryLabel = NSTextView(forAutoLayout: ())
    public let unreadCounter = UnreadCounter()
    public let imageView = NSImageView(forAutoLayout: ())

    var nameHeight: NSLayoutConstraint? = nil

    public override func mouseUp(with theEvent: NSEvent) {
        if let feed = self.feed {
            self.delegate?.didClickFeed(feed)
        }
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        guard let feed = self.feed else {
            return nil
        }
        let menu = NSMenu(title: "")
        if let menuOptions = self.delegate?.menuOptionsForFeed(feed) {
            for option in menuOptions {
                let menuItem = NSMenuItem(title: option,
                                          action: #selector(FeedView.didSelectMenuItem(_:)),
                                          keyEquivalent: "")
                menuItem.target = self
                menu.addItem(menuItem)
            }
        }
        return menu
    }

    internal func didSelectMenuItem(_ menuItem: NSMenuItem) {
        guard let feed = self.feed else {
            return
        }
        self.delegate?.didSelectMenuOption(menuItem.title, forFeed: feed)
    }

    // swiftlint:disable function_body_length
    public override init(frame: NSRect) {
        super.init(frame: frame)

        self.addSubview(self.nameLabel)
        self.addSubview(self.summaryLabel)
        self.addSubview(self.imageView)
        self.addSubview(self.unreadCounter)
        self.unreadCounter.translatesAutoresizingMaskIntoConstraints = false

        self.unreadCounter.autoPinEdge(toSuperviewEdge: .top)
        self.unreadCounter.autoPinEdge(toSuperviewEdge: .right)
        self.unreadCounter.autoSetDimensions(to: CGSize(width: 30, height: 30))
        self.unreadCounter.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)

        self.nameLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 4)
        self.nameLabel.autoPinEdge(.right, to: .left, of: unreadCounter, withOffset: -8)
        self.nameLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        self.nameHeight = nameLabel.autoSetDimension(.height, toSize: 22)
        self.nameLabel.backgroundColor = NSColor.clear

        self.summaryLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 4)
        self.summaryLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 8)
        self.summaryLabel.autoPinEdge(.top,
                                      to: .bottom,
                                      of: nameLabel,
                                      withOffset: 8,
                                      relation: .greaterThanOrEqual)
        self.summaryLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        self.summaryLabel.backgroundColor = NSColor.clear

        self.imageView.autoPinEdge(toSuperviewEdge: .trailing)
        self.imageView.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
        self.imageView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
        self.imageView.autoAlignAxis(toSuperviewAxis: .horizontal)

        for textView in [self.nameLabel, self.summaryLabel] {
            textView.textContainerInset = NSSize.zero
            textView.isEditable = false
            textView.isSelectable = false
            textView.font = NSFont.systemFont(ofSize: 12)
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
