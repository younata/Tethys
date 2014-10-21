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
                let request = NSURLRequest(URL: NSURL(string: a.link)!)
                if let cnt = a.content ?? a.summary {
                    self.content.loadHTMLString(cnt, baseURL: NSURL(string: a.feed.url)!)
                } else {
                    self.content.loadRequest(NSURLRequest(URL: NSURL(string: a.link)!))
                    if (shareButton != nil) {
                        self.toolbarItems = [spacer(), shareButton, spacer()]
                    }
                }
                self.navigationItem.title = a.title
            }
        }
    }
    
    enum ArticleContentType {
        case Content;
        case Link;
    }
    
    let content = WKWebView(forAutoLayout: ())
    let loadingBar = UIProgressView(progressViewStyle: .Bar)
    
    var shareButton: UIBarButtonItem! = nil
    var toggleContentButton: UIBarButtonItem! = nil
    let contentString = NSLocalizedString("Content", comment: "")
    let linkString = NSLocalizedString("Link", comment: "")
    
    var contentType: ArticleContentType = .Content {
        didSet {
            if let a = article {
                switch (contentType) {
                case .Content:
                    toggleContentButton.title = linkString
                    self.content.loadHTMLString(a.content ?? a.summary ?? "", baseURL: NSURL(string: a.feed.url))
                case .Link:
                    toggleContentButton.title = contentString
                    self.content.loadRequest(NSURLRequest(URL: NSURL(string: a.link)!))
                }
            }
        }
    }
    
    func spacer() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(content)
        content.setTranslatesAutoresizingMaskIntoConstraints(false)
        content.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        content.navigationDelegate = self
        content.configuration.preferences.minimumFontSize = 16.0
        
        content.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
        
        let back = UIBarButtonItem(title: "<", style: .Plain, target: content, action: "goBack")
        let forward = UIBarButtonItem(title: ">", style: .Plain, target: content, action: "goForward")
        back.enabled = false
        forward.enabled = false
        
        self.navigationItem.rightBarButtonItems = [forward, back]
        self.navigationController?.toolbarHidden = false
        // share, show (content|link)...
        var shareButton = UIBarButtonItem(barButtonSystemItem: .Compose, target: self, action: "share")
        toggleContentButton = UIBarButtonItem(title: linkString, style: .Plain, target: self, action: "toggleContentLink")
        if let a = article {
            if (a.content ?? a.summary) != nil {
                self.toolbarItems = [spacer(), shareButton, spacer(), toggleContentButton, spacer()]
            } else {
                self.toolbarItems = [spacer(), shareButton, spacer()]
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.toolbarHidden = false
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.toolbarHidden = true
    }
    
    deinit {
        content.removeObserver(self, forKeyPath: "estimatedProgress")
    }
    
    func share() {
        if let a = article {
            let activity = UIActivityViewController(activityItems: [NSURL(string: a.link)!], applicationActivities: nil)
            if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
                let popover = UIPopoverController(contentViewController: activity)
                popover.presentPopoverFromBarButtonItem(shareButton, permittedArrowDirections: .Any, animated: true)
            } else {
                self.presentViewController(activity, animated: true, completion: nil)
            }
        }
    }
    
    func toggleContentLink() {
        
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
