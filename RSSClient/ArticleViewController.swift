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
            self.navigationController?.setToolbarHidden(article != nil, animated: true)
            if let a = article {
                a.read = true
                NSNotificationCenter.defaultCenter().postNotificationName("ArticleWasRead", object: a)
                a.managedObjectContext?.save(nil)
                let request = NSURLRequest(URL: NSURL(string: a.link)!)
                if let cnt = a.content ?? a.summary {
                    self.content.loadHTMLString(articleCSS + cnt + "</body></html>", baseURL: NSURL(string: a.feed.url)!)
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
    
    var articles: [Article] = []
    var lastArticleIndex = 0
    
    var articleCSS : String {
        if let loc = NSBundle.mainBundle().URLForResource("article", withExtension: "css") {
            if let str = NSString(contentsOfURL: loc, encoding: NSUTF8StringEncoding, error: nil) {
                return "<html><head><style type=\"text/css\">\(str)</style></head><body>"
            }
        }
        return "<html><body>"
    }
    
    var contentType: ArticleContentType = .Content {
        didSet {
            if let a = article {
                switch (contentType) {
                case .Content:
                    toggleContentButton.title = linkString
                    let cnt = a.content ?? a.summary ?? ""
                    self.content.loadHTMLString(articleCSS + cnt + "</body></html>", baseURL: NSURL(string: a.feed.url))
                case .Link:
                    toggleContentButton.title = contentString
                    self.content.loadRequest(NSURLRequest(URL: NSURL(string: a.link)!))
                }
                if (shareButton != nil && toggleContentButton != nil) {
                    if (a.content ?? a.summary) != nil {
                        self.toolbarItems = [spacer(), shareButton, spacer(), toggleContentButton, spacer()]
                    } else {
                        self.toolbarItems = [spacer(), shareButton, spacer()]
                    }
                }
            } else {
                self.toolbarItems = []
                self.content.loadHTMLString("", baseURL: nil)
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
        
        self.view.addSubview(loadingBar)
        loadingBar.setTranslatesAutoresizingMaskIntoConstraints(false)
        loadingBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        
        if let splitView = self.splitViewController {
            self.navigationItem.leftBarButtonItem = splitView.displayModeButtonItem()
        }
        
        let back = UIBarButtonItem(title: "<", style: .Plain, target: content, action: "goBack")
        let forward = UIBarButtonItem(title: ">", style: .Plain, target: content, action: "goForward")
        back.enabled = false
        forward.enabled = false
        
        self.navigationItem.rightBarButtonItems = [forward, back]
        self.navigationController?.setToolbarHidden(article != nil, animated: true)
        // share, show (content|link)...
        shareButton = UIBarButtonItem(barButtonSystemItem: .Compose, target: self, action: "share")
        toggleContentButton = UIBarButtonItem(title: linkString, style: .Plain, target: self, action: "toggleContentLink")
        if let a = article {
            if (a.content ?? a.summary) != nil {
                self.toolbarItems = [spacer(), shareButton, spacer(), toggleContentButton, spacer()]
            } else {
                self.toolbarItems = [spacer(), shareButton, spacer()]
            }
        }
        
        let swipeRight = UIScreenEdgePanGestureRecognizer(target: self, action: "next:")
        swipeRight.edges = .Right
        self.view.addGestureRecognizer(swipeRight)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setToolbarHidden(article != nil, animated: true)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.toolbarHidden = true
    }
    
    func next(gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .Ended {
            // FIXME: animate this.
            if lastArticleIndex + 1 >= articles.count {
                
            } else {
                lastArticleIndex++
                article = articles[lastArticleIndex]
            }
        }
    }
    
    func share() {
        if let a = article {
            let share = TUSafariActivity()
            let activity = UIActivityViewController(activityItems: [NSURL(string: a.link)!], applicationActivities: [share])
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                let popover = UIPopoverController(contentViewController: activity)
                popover.presentPopoverFromBarButtonItem(shareButton, permittedArrowDirections: .Any, animated: true)
            } else {
                self.presentViewController(activity, animated: true, completion: nil)
            }
        }
    }
    
    func toggleContentLink() {
        switch (self.contentType) {
        case .Link:
            self.contentType = .Content
        case .Content:
            self.contentType = .Link
        }
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (keyPath == "estimatedProgress" && object as NSObject == content) {
            loadingBar.progress = Float(content.estimatedProgress)
        }
    }
    
    func webView(webView: WKWebView!, didFinishNavigation navigation: WKNavigation!) {
        let forward = (self.navigationItem.rightBarButtonItems![0] as UIBarButtonItem)
        let back = (self.navigationItem.rightBarButtonItems![1] as UIBarButtonItem)
        forward.enabled = webView.canGoForward
        back.enabled = webView.canGoBack
        loadingBar.hidden = true
    }
    
    func webView(webView: WKWebView!, didFailNavigation navigation: WKNavigation!, withError error: NSError!) {
        loadingBar.hidden = true
    }
    
    func webView(webView: WKWebView!, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadingBar.progress = 0
        loadingBar.hidden = false
    }
}
