//
//  SettingsCell.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/25/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class SettingsCell: UITableViewCell {
    
    enum SettingType {
        case Bool
        case String
    }
    
    var type : SettingType = .Bool
    
    var name : String = "" {
        didSet {
            label.text = name
        }
    }
    
    var onChange : (AnyObject) -> (Void) = {(_) in }
    
    private let label = UILabel(forAutoLayout: ())
    private var control : UIControl? = nil
    
    func configure(initialValue: AnyObject) {
        for view in self.contentView.subviews as [UIView] {
            view.removeFromSuperview()
        }
        self.contentView.addSubview(label)
        label.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        label.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        label.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4, relation: .GreaterThanOrEqual)
        
        switch (type) {
        case .Bool:
            let sw = UISwitch(forAutoLayout: ())
            sw.on = initialValue as Bool
            control = sw
            self.contentView.addSubview(sw)
        case .String:
            break
        }
        control?.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        control?.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        control?.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4)
        control?.addTarget(self, action: "valueChanged", forControlEvents: .ValueChanged)
    }
    
    func valueChanged() {
        switch (type) {
        case .Bool:
            let value = (control as UISwitch).on
            onChange(value)
        case .String:
            break
        }
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .None
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
