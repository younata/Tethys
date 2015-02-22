//
//  FindFeedViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/28/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit
import WebKit

class FindFeedViewController: UIViewController, WKNavigationDelegate, UITextFieldDelegate {
    let webContent = WKWebView(forAutoLayout: ())
    let loadingBar = UIProgressView(progressViewStyle: .Bar)
    let navField = UITextField(frame: CGRectMake(0, 0, 200, 30))
    private var rssLink: String? = nil
    
    var addFeedButton: UIBarButtonItem! = nil
    var back: UIBarButtonItem! = nil
    var forward: UIBarButtonItem! = nil
    var reload: UIBarButtonItem! = nil
    var cancelTextEntry : UIBarButtonItem! = nil
    
    var lookForFeeds : Bool = true
    
    var feeds: [String] = []
    
    lazy var dataManager : DataManager = { self.injector!.create(DataManager.self) as DataManager }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = .None
        
        webContent.navigationDelegate = self
        self.view.addSubview(webContent)
        webContent.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        
        webContent.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
                
        back = UIBarButtonItem(title: "<", style: .Plain, target: webContent, action: "goBack")
        forward = UIBarButtonItem(title: ">", style: .Plain, target: webContent, action: "goForward")
        addFeedButton = UIBarButtonItem(title: NSLocalizedString("Add Feed", comment: ""), style: .Plain, target: self, action: "save")
        back.enabled = false
        forward.enabled = false
        addFeedButton.enabled = false
        
        let dismiss = UIBarButtonItem(title: NSLocalizedString("Dismiss", comment: ""), style: .Plain, target: self, action: "dismiss")
        reload = UIBarButtonItem(barButtonSystemItem: .Refresh, target: webContent, action: "reload")
        cancelTextEntry = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: ""), style: .Plain, target: navField, action: "resignFirstResponder")
        cancelTextEntry.tintColor = UIColor.darkTextColor()
        
        self.navigationController?.toolbarHidden = false
        func spacer() -> UIBarButtonItem {
            return UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: "")
        }
        if (lookForFeeds) {
            self.toolbarItems = [back, forward, spacer(), dismiss, spacer(), addFeedButton]
        } else {
            self.toolbarItems = [back, forward, spacer(), dismiss]
        }
        
        self.navigationItem.titleView = navField
        navField.delegate = self
        navField.placeholder = "Enter URL"
        navField.backgroundColor = UIColor(white: 0.8, alpha: 0.75)
        navField.layer.cornerRadius = 5
        navField.autocorrectionType = .No
        navField.autocapitalizationType = .None
        navField.keyboardType = .URL
        navField.clearsOnBeginEditing = true
        
        loadingBar.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.view.addSubview(loadingBar)
        loadingBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        loadingBar.autoSetDimension(.Height, toSize: 1)
        loadingBar.progress = 0
        loadingBar.hidden = true
        loadingBar.progressTintColor = UIColor.darkGreenColor()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if (lookForFeeds) {
            feeds = dataManager.feeds().reduce([], combine: {
                if $1.url == nil {
                    return $0
                }
                return $0 + [$1.url]
            })
        }
    }
    
    deinit {
        webContent.removeObserver(self, forKeyPath: "estimatedProgress")
    }
    
    func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func save() {
        if let rl = rssLink {
            save(rl)
        } else {
            dismiss()
        }
    }
    
    func save(link: String, opml: Bool = false) {
        // show something to indicate we're doing work...
        let loading = LoadingView(frame: self.view.bounds)
        self.view.addSubview(loading)
        loading.msg = NSString.localizedStringWithFormat(NSLocalizedString("Loading feed at %@", comment: ""), link)
        if opml {
            dataManager.importOPML(NSURL(string: link)!, progress: {(_) in }) {(_) in
                loading.removeFromSuperview()
                self.navigationController?.toolbarHidden = false
                self.navigationController?.navigationBarHidden = false
                self.dismiss()
            }
        } else {
            dataManager.newFeed(link) {(error) in
                if let err = error {
                    println("\(err)")
                }
                loading.removeFromSuperview()
                self.navigationController?.toolbarHidden = false
                self.navigationController?.navigationBarHidden = false
                self.dismiss()
            }
        }
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (keyPath == "estimatedProgress" && object as NSObject == webContent) {
            loadingBar.progress = Float(webContent.estimatedProgress)
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldDidBeginEditing(textField: UITextField) {
        self.navigationItem.setRightBarButtonItem(cancelTextEntry, animated: true)
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        var button : UIBarButtonItem? = nil
        if (webContent.estimatedProgress >= 1.0) {
            button = reload
        }
        self.navigationItem.setRightBarButtonItem(button, animated: true)
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.text = textField.text.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        if !textField.text.lowercaseString.hasPrefix("http") {
            textField.text = "http://\(textField.text)"
        }
        if let url = NSURL(string: textField.text) {
            self.webContent.loadRequest(NSURLRequest(URL: NSURL(string: textField.text)!))
        }
        if (lookForFeeds) {
            let text = textField.text!
            request(.GET, text).responseString {(_, _, response, error) in
                if let txt = response {
                    let feedParser = FeedParser(string: txt)
                    feedParser.parseInfoOnly = true
                    let opmlParser = OPMLParser(text: txt).success{(_) in
                        feedParser.stopParsing()
                        let alert = UIAlertController(title: NSLocalizedString("Feed list Detected", comment: ""), message: NSLocalizedString("Import?", comment: ""), preferredStyle: .Alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("Don't Save", comment: ""), style: .Cancel, handler: {(alertAction: UIAlertAction!) in
                            print("") // this is bullshit
                            alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                        }))
                        alert.addAction(UIAlertAction(title: NSLocalizedString("Save", comment: ""), style: .Default, handler: {(_) in
                            alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                            self.save(textField.text, opml: true)
                        }))
                        self.presentViewController(alert, animated: true, completion: nil)
                    }
                    feedParser.success {(info, _) in
                        let string = info.url != nil ? info.url.absoluteString! : text
                        opmlParser.stopParsing()
                        if (!contains(self.feeds, textField.text)) {
                            let alert = UIAlertController(title: NSLocalizedString("Feed Detected", comment: ""), message: NSString.localizedStringWithFormat(NSLocalizedString("Save %@?", comment: ""), textField.text), preferredStyle: .Alert)
                            alert.addAction(UIAlertAction(title: NSLocalizedString("Don't Save", comment: ""), style: .Cancel, handler: {(alertAction: UIAlertAction!) in
                                print("") // this is bullshit
                                alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                            }))
                            alert.addAction(UIAlertAction(title: NSLocalizedString("Save", comment: ""), style: .Default, handler: {(_) in
                                alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                                self.save(string, opml: false)
                            }))
                            self.presentViewController(alert, animated: true, completion: nil)
                        }
                    }
                    feedParser.parse()
                    opmlParser.parse()
                }
            }
        }
        textField.text = ""
        textField.placeholder = NSLocalizedString("Loading", comment: "")
        textField.resignFirstResponder()
        
        return true
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(webView: WKWebView!, didFinishNavigation navigation: WKNavigation!) {
        self.navigationItem.titleView = self.navField
        navField.placeholder = webView.title
        forward.enabled = webView.canGoForward
        back.enabled = webView.canGoBack
        self.navigationItem.rightBarButtonItem = reload
        
        if (lookForFeeds) {
            let discover = NSString(contentsOfFile: NSBundle.mainBundle().pathForResource("findFeeds", ofType: "js")!, encoding: NSUTF8StringEncoding, error: nil)!
            webView.evaluateJavaScript(discover, completionHandler: {(res: AnyObject!, error: NSError?) in
                if let str = res as? String {
                    if (!contains(self.feeds, str)) {
                        self.rssLink = str
                        self.addFeedButton.enabled = true
                    }
                } else {
                    self.rssLink = nil
                }
                if (error != nil) {
                    println("Error executing javascript: \(error)")
                }
            })
        }
        loadingBar.hidden = true
    }
    
    func webView(webView: WKWebView!, didFailNavigation navigation: WKNavigation!, withError error: NSError!) {
        self.navigationItem.titleView = self.navField
        loadingBar.hidden = true
    }
    
    func webView(webView: WKWebView!, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadingBar.progress = 0
        loadingBar.hidden = false
        navField.placeholder = ""
        addFeedButton.enabled = false
    }
}
