//
//  ArticleViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit
import WebKit

class ArticleViewController: UIViewController, WKNavigationDelegate {
    
    var article: Article? = nil {
        didSet {
            if let a = article {
                let request = NSURLRequest(URL: NSURL(string: a.link))
                self.content.loadRequest(request)
            }
        }
    }
    
    let content = WKWebView(forAutoLayout: ())

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(content)
        
        let back = UIBarButtonItem(title: "<", style: .Plain, target: content, action: "goBack")
        let forward = UIBarButtonItem(title: ">", style: .Plain, target: content, action: "goForward")
        back.enabled = false
        forward.enabled = false
        
        self.navigationItem.rightBarButtonItems = [forward, back]
    }
    
    func webView(webView: WKWebView!, didFinishNavigation navigation: WKNavigation!) {
        self.navigationItem.title = webView.title
        let forward = (self.navigationItem.rightBarButtonItems![0] as UIBarButtonItem)
        let back = (self.navigationItem.rightBarButtonItems![1] as UIBarButtonItem)
        forward.enabled = webView.canGoForward
        back.enabled = webView.canGoBack
    }
}
