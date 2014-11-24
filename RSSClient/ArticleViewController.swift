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
            self.navigationController?.setToolbarHidden(article == nil, animated: true)
            if let a = article {
                a.read = true
                NSNotificationCenter.defaultCenter().postNotificationName("ArticleWasRead", object: a)
                a.managedObjectContext?.save(nil)
                let url = NSURL(string: a.link)!
                var hasContent = false
                if let cnt = a.content ?? a.summary {
                    self.content.loadHTMLString(articleCSS + cnt + "</body></html>", baseURL: NSURL(string: a.feed.url)!)
                    if let sb = shareButton {
                        self.toolbarItems = [spacer(), sb, spacer(), toggleContentButton, spacer()]
                    }
                    hasContent = true
                } else {
                    self.content.loadRequest(NSURLRequest(URL: NSURL(string: a.link)!))
                    if let sb = shareButton {
                        self.toolbarItems = [spacer(), sb, spacer()]
                    }
                }
                self.navigationItem.title = a.title
                
                if userActivity == nil {
                    userActivity = NSUserActivity(activityType: "com.rachelbrindle.rssclient.article")
                    userActivity?.title = NSLocalizedString("Reading Article", comment: "")
                    userActivity?.becomeCurrent()
                }
                userActivity?.userInfo = ["feed": a.feed.title, "article": a.title, "showingContent": hasContent, "url": (hasContent ? url : NSNull())]
                userActivity?.webpageURL = NSURL(string: a.link)
                self.userActivity?.needsSave = true
                
                let notes : [UILocalNotification] = (UIApplication.sharedApplication().scheduledLocalNotifications as [UILocalNotification]).filter {(note) in
                    if let ui = note.userInfo {
                        if let feed : String = ui["feed"] as? String {
                            if let title : String = ui["article"] as? String {
                                return feed == a.feed.title && title == a.title
                            }
                        }
                    }
                    return false
                }
                
                for note in notes {
                    UIApplication.sharedApplication().cancelLocalNotification(note)
                }
            }
        }
    }
    
    enum ArticleContentType {
        case Content;
        case Link;
    }
    
    var content = WKWebView(forAutoLayout: ())
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
        
        self.edgesForExtendedLayout = .None
        
        if userActivity == nil {
            userActivity = NSUserActivity(activityType: "com.rachelbrindle.rssclient.article")
            userActivity?.title = NSLocalizedString("Reading Article", comment: "")
        }
        
        self.view.addSubview(content)
        content.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        configureContent()
        
        self.view.addSubview(loadingBar)
        loadingBar.setTranslatesAutoresizingMaskIntoConstraints(false)
        loadingBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        loadingBar.autoSetDimension(.Height, toSize: 2)
        
        if let splitView = self.splitViewController {
            // don't set this if ipad or iphone 6+ in normal mode...
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad || false {
                // if iphone6+ in normal...
                self.navigationItem.leftBarButtonItem = splitView.displayModeButtonItem()
            }
        }
        
        let back = UIBarButtonItem(title: "<", style: .Plain, target: content, action: "goBack")
        let forward = UIBarButtonItem(title: ">", style: .Plain, target: content, action: "goForward")
        back.enabled = false
        forward.enabled = false
        
        self.navigationItem.rightBarButtonItems = [forward, back]
        self.navigationController?.setToolbarHidden(article == nil, animated: true)
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
        let swipeLeft = UIScreenEdgePanGestureRecognizer(target: self, action: "back:")
        swipeLeft.edges = .Left
        self.view.addGestureRecognizer(swipeLeft)
    }
    
    override func restoreUserActivityState(activity: NSUserActivity) {
        super.restoreUserActivityState(activity)
        
        if let ui = activity.userInfo {
            let showingContent = (ui["showingContent"] as Bool)
            if showingContent {
                self.contentType = .Content
            } else {
                self.contentType = .Link
            }
            if let url = ui["url"] as? NSURL {
                self.content.loadRequest(NSURLRequest(URL: url))
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setToolbarHidden(article == nil, animated: true)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.toolbarHidden = true
        userActivity?.invalidate()
        userActivity = nil
    }
    
    deinit {
        userActivity?.invalidate()
    }
    
    func configureContent() {
        content.navigationDelegate = self
    }
    
    var nextContent: WKWebView = WKWebView(forAutoLayout: ())
    var nextContentRight : NSLayoutConstraint! = nil
    
    func back(gesture: UIScreenEdgePanGestureRecognizer) {
        if lastArticleIndex == 0 {
            return
        }
        let width = CGRectGetWidth(self.view.bounds)
        let translation = width - gesture.translationInView(self.view).x
        if gesture.state == .Began {
            let a = articles[lastArticleIndex-1]
            nextContent = WKWebView(forAutoLayout: ())
            self.view.addSubview(nextContent)
            if let cnt = a.content ?? a.summary {
                self.content.loadHTMLString(articleCSS + cnt + "</body></html>", baseURL: NSURL(string: a.feed.url)!)
            } else {
                let request = NSURLRequest(URL: NSURL(string: a.link)!)
                self.content.loadRequest(request)
            }
            nextContent.autoPinEdgeToSuperviewEdge(.Top)
            nextContent.autoPinEdgeToSuperviewEdge(.Bottom)
            nextContent.autoMatchDimension(.Width, toDimension: .Width, ofView: self.view)
            nextContentRight = nextContent.autoPinEdgeToSuperviewEdge(.Right, withInset: translation)
        } else if gesture.state == .Changed {
            nextContentRight.constant = translation
        } else if gesture.state == .Cancelled {
            nextContent.removeFromSuperview()
        } else if gesture.state == .Ended {
            let speed = gesture.velocityInView(self.view).x
            if speed >= 0 {
                lastArticleIndex--
                article = articles[lastArticleIndex]
                nextContentRight.constant = 0
                content = nextContent
                configureContent()
                UIView.animateWithDuration(0.2, animations: {
                    self.view.layoutIfNeeded()
                }, completion: {(completed) in
                    self.view.bringSubviewToFront(self.loadingBar)
                })
            } else {
                nextContent.removeFromSuperview()
            }
        }
    }
    
    func next(gesture: UIScreenEdgePanGestureRecognizer) {
        if lastArticleIndex + 1 >= articles.count {
            return;
        }
        let width = CGRectGetWidth(self.view.bounds)
        let translation = width + gesture.translationInView(self.view).x
        if gesture.state == .Began {
            let a = articles[lastArticleIndex+1]
            nextContent = WKWebView(forAutoLayout: ())
            self.view.addSubview(nextContent)
            if let cnt = a.content ?? a.summary {
                nextContent.loadHTMLString(articleCSS + cnt + "</body></html>", baseURL: NSURL(string: a.feed.url)!)
            } else {
                let request = NSURLRequest(URL: NSURL(string: a.link)!)
                nextContent.loadRequest(request)
            }
            nextContent.autoPinEdgeToSuperviewEdge(.Top)
            nextContent.autoPinEdgeToSuperviewEdge(.Bottom)
            nextContent.autoMatchDimension(.Width, toDimension: .Width, ofView: self.view)
            nextContentRight = nextContent.autoPinEdgeToSuperviewEdge(.Right, withInset: translation)
        } else if gesture.state == .Changed {
            nextContentRight.constant = translation
        } else if gesture.state == .Cancelled {
            nextContent.removeFromSuperview()
        } else if gesture.state == .Ended {
            let speed = gesture.velocityInView(self.view).x * -1
            if speed >= 0 {
                lastArticleIndex++
                article = articles[lastArticleIndex]
                nextContentRight.constant = 0
                content = nextContent
                configureContent()
                UIView.animateWithDuration(0.2, animations: {
                    self.view.layoutIfNeeded()
                }, completion: {(completed) in
                    self.view.bringSubviewToFront(self.loadingBar)
                })
            } else {
                nextContent.removeFromSuperview()
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
            self.userActivity?.userInfo?["showingContent"] = true
            self.userActivity?.userInfo?["url"] = NSNull()
        case .Content:
            self.contentType = .Link
            self.userActivity?.userInfo?["showingContent"] = false
            self.userActivity?.userInfo?["url"] = NSURL(string: self.article!.link)!
        }
        self.userActivity?.needsSave = true
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
        if let wvu = webView.URL {
            self.userActivity?.userInfo?["url"] = wvu
            self.userActivity?.needsSave = true
            self.userActivity?.webpageURL = wvu
        }
    }
}
