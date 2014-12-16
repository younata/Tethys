//
//  BackgroundView.swift
//  RSSClient
//
//  Created by Rachel Brindle on 12/15/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Cocoa

class BackgroundView: NSView {
    
    @IBInspectable var backgroundColor: NSColor = NSColor.clearColor()
    @IBInspectable var lineColor : NSColor = NSColor.blackColor()

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        let context = NSGraphicsContext.currentContext()
        CGContextSetFillColorWithColor(context?.CGContext, backgroundColor.CGColor)
        CGContextFillRect(context?.CGContext, dirtyRect)
        
        CGContextSetStrokeColorWithColor(context?.CGContext, lineColor.CGColor)
        CGContextMoveToPoint(context?.CGContext, 0, 0)
        CGContextAddLineToPoint(context?.CGContext, dirtyRect.width, 0)
        CGContextSetLineWidth(context?.CGContext, 1)
        CGContextStrokePath(context?.CGContext)
    }
    
}
