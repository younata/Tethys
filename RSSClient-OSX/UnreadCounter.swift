//
//  UnreadCounter.swift
//  RSSClient
//
//  Created by Rachel Brindle on 12/11/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Cocoa

class UnreadCounter: NSView {
    
    let triangleLayer = CAShapeLayer()
    let countLabel = NSText(forAutoLayout: ())
    
    var triangleColor: NSColor = NSColor.darkGreenColor()
    var countColor: NSColor = NSColor.whiteColor() {
        didSet {
            countLabel.textColor = countColor
        }
    }
    
    var hideUnreadText = false
    var unread : UInt = 0 {
        didSet {
            if unread == 0 {
                countLabel.string = ""
                triangleLayer.fillColor = NSColor.clearColor().CGColor
            } else {
                if hideUnreadText {
                    countLabel.string = ""
                } else {
                    countLabel.string = "\(unread)"
                }
                triangleLayer.fillColor = triangleColor.CGColor
            }
        }
    }
    
    override func layout() {
        super.layout()
        let path = CGPathCreateMutable()
        let height = CGRectGetHeight(self.bounds)
        let width = CGRectGetWidth(self.bounds)
        CGPathMoveToPoint(path, nil, 0, height)
        CGPathAddLineToPoint(path, nil, width, height)
        CGPathAddLineToPoint(path, nil, width, 0)
        CGPathAddLineToPoint(path, nil, 0, height)
        triangleLayer.path = path
    }
    
    override init() {
        super.init()
        self.layer = CALayer()
        self.wantsLayer = true
        
        self.layer!.addSublayer(triangleLayer)
        self.addSubview(countLabel)
        countLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 4)
        countLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        countLabel.editable = false
        countLabel.alignment = .RightTextAlignment
        countLabel.textColor = countColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
    }
    
}
