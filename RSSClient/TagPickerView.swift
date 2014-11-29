//
//  TagPickerView.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class TagPickerView: UIView, UIPickerViewDataSource, UIPickerViewDelegate {
    let picker = UIPickerView(forAutoLayout: ())
    
    let textField = UITextField(forAutoLayout: ())
    
    var value : String {
        get {
            return ""
        }
    }
    
    // MARK: UIPickerView protocols
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 0
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        return ""
    }
}
