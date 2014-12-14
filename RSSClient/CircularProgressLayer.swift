//
//  CircularProgressLayer.swift
//  RSSClient
//
//  Created by Rachel Brindle on 12/13/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class CircularProgressLayer: CAShapeLayer {
    var progress : Double = 0.0 {
        didSet {
            reDraw()
        }
    }
    
    var width : CGFloat = 2.0 {
        didSet {
            reDraw()
        }
    }
    
    func reDraw() {
        let path = CGPathCreateMutable()
        let outerRadius = self.bounds.width / 2
        let innerRadius = outerRadius - width
        let center = CGPointMake(outerRadius, self.bounds.height / 2)
        
        let startAngle = CGFloat(-(M_PI / 2))
        let endAngle = CGFloat((M_PI * 2) * progress) - startAngle
        
        CGPathAddArc(path, nil, center.x, center.y, outerRadius, startAngle, endAngle, true)
        CGPathAddLineToPoint(path, nil, innerRadius * cos(endAngle), innerRadius * sin(endAngle))
        CGPathAddArc(path, nil, center.x, center.y, innerRadius, endAngle, startAngle, false)
        CGPathAddLineToPoint(path, nil, self.bounds.width / 2, self.bounds.height / 2)
        
        self.path = path
    }
}
