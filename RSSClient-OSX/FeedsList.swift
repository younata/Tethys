//
//  FeedsList.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/21/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Cocoa

class FeedsList: NSViewController {
    var feeds : [Feed] = []
    
    var list = NSOutlineView(forAutolayout: ())
    
    func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(list)
        
    }
}
