import Cocoa
import PureLayout
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
        super.init(frame: NSRect.zero)

        self.addSubview(countLabel)
        countLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 4)
        countLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 4)
        countLabel.isEditable = false
        countLabel.alignment = .right
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
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: 0, y: height))
        ctx?.cgContext.addPath(path)
        ctx?.cgContext.setFillColor(self.color.cgColor)
        (ctx?.cgContext)?.fillPath()
    }
}
