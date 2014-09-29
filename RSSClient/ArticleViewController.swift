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
                println("Article: \(a)")
                let request = NSURLRequest(URL: NSURL(string: a.link))
                println("Loading \(a.link)")
                self.content.loadRequest(request)
                self.navigationItem.title = a.title
            }
        }
    }
    
    let content = WKWebView(forAutoLayout: ())
    let loadingBar = UIProgressView(progressViewStyle: .Bar)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(content)
        content.setTranslatesAutoresizingMaskIntoConstraints(false)
        content.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        content.navigationDelegate = self
        
        content.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
        
        let back = UIBarButtonItem(title: "<", style: .Plain, target: content, action: "goBack")
        let forward = UIBarButtonItem(title: ">", style: .Plain, target: content, action: "goForward")
        back.enabled = false
        forward.enabled = false
        
        self.navigationItem.rightBarButtonItems = [forward, back]
    }
    
    deinit {
        content.removeObserver(self, forKeyPath: "estimatedProgress")
    }
    
    override func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [NSObject : AnyObject]!, context: UnsafeMutablePointer<Void>) {
        if (keyPath == "estimatedProgress" && object as NSObject == content) {
            loadingBar.progress = Float(content.estimatedProgress)
        }
    }
    
    func webView(webView: WKWebView!, didFinishNavigation navigation: WKNavigation!) {
        self.navigationItem.titleView = nil
        self.navigationItem.title = webView.title
        let forward = (self.navigationItem.rightBarButtonItems![0] as UIBarButtonItem)
        let back = (self.navigationItem.rightBarButtonItems![1] as UIBarButtonItem)
        forward.enabled = webView.canGoForward
        back.enabled = webView.canGoBack
    }
    
    func webView(webView: WKWebView!, didFailNavigation navigation: WKNavigation!, withError error: NSError!) {
        self.navigationItem.titleView = nil
    }
    
    func webView(webView: WKWebView!, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadingBar.progress = 0
        self.navigationItem.titleView = loadingBar
    }
}
