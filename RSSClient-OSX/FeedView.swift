import Cocoa
import rNewsKit

public class FeedView: NSView {
    public var feed: Feed? = nil {
        didSet {
            if let f = feed {
                self.nameLabel.string = f.title
                let font : NSFont = nameLabel.font!
                self.nameHeight?.constant = ceil(NSAttributedString(string: nameLabel.string!, attributes: [NSFontAttributeName: font]).size().height)
                self.summaryLabel.string = f.summary
                self.unreadCounter.unread = UInt(f.articles.filter({return $0.read == false}).count)
                self.imageView.image = f.image
            } else {
                self.nameLabel.string = ""
                self.summaryLabel.string = ""
                self.unreadCounter.unread = 0
            }
        }
    }
    
    public let nameLabel = NSTextView(forAutoLayout: ())
    public let summaryLabel = NSTextView(forAutoLayout: ())
    public let unreadCounter = UnreadCounter()
    public let imageView = NSImageView(forAutoLayout: ())
    
    var nameHeight : NSLayoutConstraint? = nil

    public override init(frame: NSRect) {
        super.init(frame: frame)
        
        self.addSubview(self.nameLabel)
        self.addSubview(self.summaryLabel)
        self.addSubview(self.imageView)
        self.addSubview(self.unreadCounter)
        self.unreadCounter.translatesAutoresizingMaskIntoConstraints = false
        
        self.unreadCounter.autoPinEdgeToSuperviewEdge(.Top)
        self.unreadCounter.autoPinEdgeToSuperviewEdge(.Right)
        self.unreadCounter.autoSetDimensionsToSize(CGSizeMake(30, 30))
        self.unreadCounter.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 0, relation: .GreaterThanOrEqual)
        
        self.nameLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        self.nameLabel.autoPinEdge(.Right, toEdge: .Left, ofView: unreadCounter, withOffset: -8)
        self.nameLabel.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        self.nameHeight = nameLabel.autoSetDimension(.Height, toSize: 22)
        self.nameLabel.backgroundColor = NSColor.clearColor()
        
        self.summaryLabel.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4)
        self.summaryLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        self.summaryLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: nameLabel, withOffset: 8, relation: .GreaterThanOrEqual)
        self.summaryLabel.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        self.summaryLabel.backgroundColor = NSColor.clearColor()

        self.imageView.autoPinEdgeToSuperviewEdge(.Trailing)
        self.imageView.autoPinEdgeToSuperviewEdge(.Top, withInset: 0, relation: .GreaterThanOrEqual)
        self.imageView.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 0, relation: .GreaterThanOrEqual)
        self.imageView.autoAlignAxisToSuperviewAxis(.Horizontal)
        
        for textView in [self.nameLabel, self.summaryLabel] {
            textView.textContainerInset = NSMakeSize(0, 0)
            textView.editable = false
            textView.selectable = false
            textView.font = NSFont.systemFontOfSize(12)
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
