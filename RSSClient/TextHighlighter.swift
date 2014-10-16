//
//  TextHighlighter.swift
//  RSSClient
//
//  Created by Rachel Brindle on 10/15/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation

protocol TextHighlighter {
    func highlight(text: String) -> NSAttributedString
}