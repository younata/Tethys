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
    
    public var circleColor: UIColor = UIColor.redColor()
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
        circleLayer.path = CGPathCreateWithEllipseInRect(self.bounds, nil)
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer.addSublayer(circleLayer)
        self.addSubview(countLabel)
        
        countLabel.autoCenterInSuperview()
        countLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        countLabel.textColor = countColor
        
        self.backgroundColor = UIColor.clearColor()
        circleLayer.strokeColor = UIColor.clearColor().CGColor
    }

    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
