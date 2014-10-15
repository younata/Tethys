//
//  UnreadCounter.swift
//  RSSClient
//
//  Created by Rachel Brindle on 10/1/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

public class UnreadCounter: UIView, UIAppearanceContainer {
    
    let circleLayer = CAShapeLayer()
    let countLabel = UILabel(forAutoLayout: ())
    
    public var circleColor: UIColor = UIColor.darkGreenColor()
    public var countColor: UIColor = UIColor.whiteColor() {
        didSet {
            countLabel.textColor = countColor
        }
    }
    
    public var hideUnreadText: Bool = false
    
    public var unread : UInt = 0 {
        didSet {
            if unread == 0 {
                countLabel.text = ""
                circleLayer.fillColor = UIColor.clearColor().CGColor
            } else {
                if hideUnreadText {
                    countLabel.text = ""
                } else {
                    countLabel.text = "\(unread)"
                }
                circleLayer.fillColor = circleColor.CGColor
            }
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        let path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 0, 0)
        CGPathAddLineToPoint(path, nil, CGRectGetWidth(self.bounds), 0)
        CGPathAddLineToPoint(path, nil, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds))
        CGPathAddLineToPoint(path, nil, 0, 0)
        circleLayer.path = path
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer.addSublayer(circleLayer)
        self.addSubview(countLabel)
        
        countLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        countLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 4)
        countLabel.textAlignment = .Right
        countLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        countLabel.textColor = countColor
        
        self.backgroundColor = UIColor.clearColor()
        circleLayer.strokeColor = UIColor.clearColor().CGColor
    }

    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
