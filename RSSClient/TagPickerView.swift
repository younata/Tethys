//
//  TagPickerView.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class TagPickerView: UIView, UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate {
    let picker = UIPickerView(forAutoLayout: ())
    
    let textField = UITextField(forAutoLayout: ())
    
    var allTags: [String] = [] {
        didSet {
            textField(textField, shouldChangeCharactersInRange: NSMakeRange(0, 0), replacementString: "")
        }
    }
    
    var existingSolutions: [String] = [] {
        didSet {
            picker.reloadComponent(0)
        }
    }
    
    var didSelect: (String) -> Void = {(_) in }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.addSubview(textField)
        textField.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        textField.autoSetDimension(.Height, toSize: 40)
        
        self.addSubview(picker)
        picker.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        picker.autoPinEdge(.Top, toEdge: .Bottom, ofView: textField)
        picker.autoSetDimension(.Height, toSize: 120)
        
        textField.delegate = self
        textField.placeholder = NSLocalizedString("Tag", comment: "")
        textField.backgroundColor = UIColor(white: 0.8, alpha: 0.75)
        textField.layer.cornerRadius = 5
        
        picker.delegate = self
        picker.dataSource = self
    }
    
    // MARK: UIPickerView protocols
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return existingSolutions.count
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        return existingSolutions[row] ?? ""
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row < existingSolutions.count {
            textField.text = existingSolutions[row]
        }
    }
    
    // UITextFieldDelegate
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let text = (textField.text as NSString).stringByReplacingCharactersInRange(range, withString: string)
        
        existingSolutions = allTags.filter {
            return $0.rangeOfString(text) != nil
        }
        didSelect(text)
        
        return true
    }
}
