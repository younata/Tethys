//
//  FindFeedViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/28/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit
import WebKit

class FindFeedViewController: UIViewController, WKNavigationDelegate {
    let content = WKWebView(forAutoLayout: ())
    let loadingBar = UIProgressView(progressViewStyle: .Bar)
    private var rssLink: String? = nil
    private var icoLink: String? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        content.navigationDelegate = self
        self.view.addSubview(content)
        content.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        
        content.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
        
        let back = UIBarButtonItem(title: "<", style: .Plain, target: content, action: "goBack")
        let forward = UIBarButtonItem(title: ">", style: .Plain, target: content, action: "goForward")
        let useThis = UIBarButtonItem(title: NSLocalizedString("Select", comment: ""), style: .Plain, target: self, action: "save")
        useThis.enabled = false
        back.enabled = false
        forward.enabled = false
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Dismiss", comment: ""), style: .Plain, target: self, action: "dismiss")
        self.navigationItem.rightBarButtonItems = [useThis, forward, back]
        
        self.navigationItem.titleView = loadingBar
        loadingBar.progress = 0;
        
        let alert = UIAlertController(title: NSLocalizedString("Load Page", comment: ""), message: NSLocalizedString("Initial page to load", comment: ""), preferredStyle: .Alert)
        alert.addTextFieldWithConfigurationHandler(nil)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Go", comment: ""), style: .Default, handler: {(action: UIAlertAction!) in
            let tf = (alert.textFields![0] as UITextField)
            if let url = NSURL.URLWithString(tf.text) {
                self.content.loadRequest(NSURLRequest(URL: NSURL(string: tf.text)))
                alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
            } else if let url = NSURL.URLWithString("http://" + tf.text) {
                self.content.loadRequest(NSURLRequest(URL: url))
                alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
            } else {
                tf.text = "";
                tf.placeholder = NSLocalizedString("Invalid URL", comment: "")
            }
            
        }))
        self.presentViewController(alert, animated: true, completion: nil)
        //self.content.loadRequest(NSURLRequest(URL: NSURL(string: "https://news.ycombinator.com")))
    }
    
    deinit {
        content.removeObserver(self, forKeyPath: "estimatedProgress")
    }
    
    func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func save() {
        content.evaluateJavaScript("", completionHandler: {(res: AnyObject!, error: NSError?) in
            if let str = res as? String {
                self.icoLink = str
            } else {
                self.icoLink = nil
            }
            if (error != nil) {
                println("Error executing javascript: \(error)")
            }
            DataManager.sharedInstance().newFeed(self.rssLink!, withICO: self.icoLink)
            self.dismiss()
        })
    }
    
    override func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [NSObject : AnyObject]!, context: UnsafeMutablePointer<Void>) {
        if (keyPath == "estimatedProgress" && object as NSObject == content) {
            loadingBar.progress = Float(content.estimatedProgress)
        }
    }
    
    func webView(webView: WKWebView!, didFinishNavigation navigation: WKNavigation!) {
        self.navigationItem.titleView = nil
        self.navigationItem.title = webView.title
        let forward = (self.navigationItem.rightBarButtonItems![1] as UIBarButtonItem)
        let back = (self.navigationItem.rightBarButtonItems![2] as UIBarButtonItem)
        forward.enabled = webView.canGoForward
        back.enabled = webView.canGoBack
        
        let discover = NSString.stringWithContentsOfFile(NSBundle.mainBundle().pathForResource("findFeeds", ofType: "js")!, encoding: NSUTF8StringEncoding, error: nil)
        webView.evaluateJavaScript(discover, completionHandler: {(res: AnyObject!, error: NSError?) in
            if let str = res as? String {
                self.rssLink = str
                (self.navigationItem.rightBarButtonItems![0] as UIBarButtonItem).enabled = true
            } else {
                self.rssLink = nil
                (self.navigationItem.rightBarButtonItems![0] as UIBarButtonItem).enabled = false
            }
            if (error != nil) {
                println("Error executing javascript: \(error)")
            }
        })
    }
    
    func webView(webView: WKWebView!, didFailNavigation navigation: WKNavigation!, withError error: NSError!) {
        println("Error loading: \(error)")
    }
    
    func webView(webView: WKWebView!, didStartProvisionalNavigation navigation: WKNavigation!) {
        println("loading navigation: \(navigation)")
        loadingBar.progress = 0
        self.navigationItem.titleView = loadingBar
    }
}
