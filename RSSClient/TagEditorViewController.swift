//
//  TagEditorViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 12/2/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class TagEditorViewController: UIViewController {
    
    var feed : Feed? = nil
    var tag: String? = nil {
        didSet {
            self.navigationItem.rightBarButtonItem?.enabled = self.feed != nil && tag != nil
        }
    }
    
    var tagIndex : Int? = nil
    
    let tagLabel = UILabel(forAutoLayout: ())
    
    let tagPicker = TagPickerView(frame: CGRectZero)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = .None
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Save", comment: ""), style: .Plain, target: self, action: "save")
        self.navigationItem.rightBarButtonItem?.enabled = false
        self.navigationItem.title = self.feed?.feedTitle() ?? ""
        
        tagPicker.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.view.addSubview(tagPicker)
        tagPicker.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(16, 8, 0, 8), excludingEdge: .Bottom)
        let dataManager = self.injector!.create(DataManager.self) as DataManager
        tagPicker.allTags = dataManager.allTags()
        tagPicker.didSelect = {
            self.tag = $0
        }
        
        self.view.addSubview(tagLabel)
        tagLabel.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        tagLabel.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        tagLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: tagPicker, withOffset: 8)
        tagLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        tagLabel.numberOfLines = 0
        tagLabel.text = NSLocalizedString("Prefixing a tag with '~' will set the title to that, minus the leading ~. Prefixing a tag with '`' will set the summary to that, minus the leading `. Tags cannot contain commas (,)", comment: "")
    }
    
    func dismiss() {
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    func save() {
        if let feed = self.feed {
            var tags = feed.allTags()
            if let ti = tagIndex {
                tags[ti] = tag!
            } else {
                tags.append(tag!)
            }
            feed.tags = tags
        }
        
        self.dismiss()
    }
}
