import Cocoa
import PureLayout_Mac
import rNewsKit

public final class UnreadCounter: NSView {

    let countLabel = NSText(forAutoLayout: ())

    var triangleColor: NSColor = NSColor.darkGreen
    var countColor: NSColor = NSColor.white {
        didSet {
            countLabel.textColor = countColor
        }
    }

    private var color: NSColor = NSColor.darkGreen

    public var hideUnreadText = false
    public var unread: UInt = 0 {
        didSet {
            if unread == 0 {
                countLabel.string = ""
                color = NSColor.clear
            } else {
                if hideUnreadText {
                    countLabel.string = ""
                } else {
                    countLabel.string = "\(unread)"
                }
                color = triangleColor
            }
            self.needsDisplay = true
        }
    }

    public override func layout() {
        super.layout()
    }

    public override init(frame: NSRect) {
        super.init(frame: NSMakeRect(0, 0, 0, 0))

        self.addSubview(countLabel)
        countLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 4)
        countLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        countLabel.editable = false
        countLabel.alignment = .Right
        countLabel.textColor = countColor
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let ctx = NSGraphicsContext.current()
        let path = CGMutablePath()
        let height = self.bounds.height
        let width = self.bounds.width
        CGPathMoveToPoint(path, nil, 0, height)
        CGPathAddLineToPoint(path, nil, width, height)
        CGPathAddLineToPoint(path, nil, width, 0)
        CGPathAddLineToPoint(path, nil, 0, height)
        ctx?.cgContext.addPath(path)
        ctx?.cgContext.setFillColor(self.color.cgColor)
        (ctx?.cgContext)?.fillPath()
    }
}
