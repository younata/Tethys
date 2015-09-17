import Cocoa
import PureLayout_Mac
import rNewsKit

class UnreadCounter: NSView {
    
    let countLabel = NSText(forAutoLayout: ())
    
    var triangleColor: NSColor = NSColor.darkGreenColor()
    var countColor: NSColor = NSColor.whiteColor() {
        didSet {
            countLabel.textColor = countColor
        }
    }
    
    private var color : NSColor = NSColor.darkGreenColor()
    
    var hideUnreadText = false
    var unread : UInt = 0 {
        didSet {
            if unread == 0 {
                countLabel.string = ""
                color = NSColor.clearColor()
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
    
    override func layout() {
        super.layout()
    }
    
    override init(frame: NSRect) {
        super.init(frame: NSMakeRect(0, 0, 0, 0))

        self.addSubview(countLabel)
        countLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 4)
        countLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        countLabel.editable = false
        countLabel.alignment = .Right
        countLabel.textColor = countColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        
        let ctx = NSGraphicsContext.currentContext()
        let path = CGPathCreateMutable()
        let height = CGRectGetHeight(self.bounds)
        let width = CGRectGetWidth(self.bounds)
        CGPathMoveToPoint(path, nil, 0, height)
        CGPathAddLineToPoint(path, nil, width, height)
        CGPathAddLineToPoint(path, nil, width, 0)
        CGPathAddLineToPoint(path, nil, 0, height)
        CGContextAddPath(ctx?.CGContext, path)
        CGContextSetFillColorWithColor(ctx?.CGContext, self.color.CGColor)
        CGContextFillPath(ctx?.CGContext)
    }
}
