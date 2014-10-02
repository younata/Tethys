//
//  UnreadCounter.swift
//  RSSClient
//
//  Created by Rachel Brindle on 10/1/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class UnreadCounter: UIView, UIAppearanceContainer {
    
    private let circleLayer = CAShapeLayer()
    private let countLabel = UILabel(forAutoLayout: ())
    
    var circleColor: UIColor = UIColor.redColor()
    var countColor: UIColor = UIColor.whiteColor() {
        didSet {
            countLabel.textColor = countColor
        }
    }
    
    var hideUnreadText: Bool = false
    
    var unread : Int = 0 {
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        circleLayer.path = CGPathCreateWithEllipseInRect(self.bounds, nil)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer.addSublayer(circleLayer)
        self.addSubview(countLabel)
        
        countLabel.autoCenterInSuperview()
        countLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        countLabel.textColor = countColor
        
        self.backgroundColor = UIColor.clearColor()
        circleLayer.strokeColor = UIColor.clearColor().CGColor
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
