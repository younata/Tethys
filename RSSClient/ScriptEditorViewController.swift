//
//  ScriptEditorViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 10/15/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class ScriptEditorViewController: UIViewController, UITextViewDelegate {
    
    private let textView = UITextView(forAutoLayout: ())
    
    var highlighter : TextHighlighter? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    func textViewDidChange(textView: UITextView) {
        if let hl = highlighter {
            textView.delegate = nil
            textView.attributedText = hl.highlight(textView.text)
            textView.delegate = self
        }
    }
}
