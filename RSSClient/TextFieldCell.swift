//
//  TextFieldCell.swift
//  RSSClient
//
//  Created by Rachel Brindle on 1/13/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import UIKit

class TextFieldCell: UITableViewCell, UITextFieldDelegate {
    
    let textField = UITextField(forAutoLayout: ())
    
    var onTextChange: (String?) -> Void = {(_) in }
    
    var showValidator: Bool = false {
        didSet {
            validView.hidden = !showValidator
        }
    }
    var validate: (String) -> Bool = {(_) in return false}
    
    let validView = ValidatorView(frame: CGRectZero)
    
    func setValid(valid: Bool) {
        validView.endValidating(valid: valid)
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubview(textField)
        textField.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Right)
        textField.delegate = self
        textField.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        
        self.contentView.addSubview(validView)
        validView.setTranslatesAutoresizingMaskIntoConstraints(false)
        validView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Left)
        validView.autoPinEdge(.Left, toEdge: .Right, ofView: textField)
        
        showValidator = false
    }
    
    required init(coder: NSCoder) {
        fatalError("")
    }
    
    // MARK: UITextFieldDelegate
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let text = (textField.text as NSString).stringByReplacingCharactersInRange(range, withString: string)
        
        if showValidator {
            validView.beginValidating()
        }
        onTextChange(text)
        
        return true
    }
}
