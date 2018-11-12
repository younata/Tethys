//
//  FakeWKNavigationAction.swift
//  Tethys
//
//  Created by Rachel Brindle on 10/13/16.
//  Copyright © 2016 Rachel Brindle. All rights reserved.
//

import Foundation
import WebKit

class FakeWKNavigationAction: WKNavigationAction {
    private var  _urlRequest: URLRequest
    override var request: URLRequest { return self._urlRequest }

    private var _type: WKNavigationType
    override var navigationType: WKNavigationType { return self._type }

    init(url: URL, navigationType: WKNavigationType) {
        self._urlRequest = URLRequest(url: url)
        self._type = navigationType
        super.init()
    }
}
