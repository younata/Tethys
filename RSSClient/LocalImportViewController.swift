//
//  LocalImportViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/14/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class LocalImportViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var opmls : [String] = []
    var feeds : [String] = []
    var items : [String] = []
    var contentsOfDirectory : [String] = []
    
    let tableViewController = UITableViewController(style: .Plain)
    
    var tableViewTopOffset: NSLayoutConstraint!

    lazy var dataManager : DataManager = { self.injector!.create(DataManager.self) as DataManager }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(self.tableViewController.tableView)
        self.tableViewController.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        tableViewTopOffset = self.tableViewController.tableView.autoPinEdgeToSuperviewEdge(.Top, withInset: CGRectGetHeight(self.navigationController!.navigationBar.frame) + (UIApplication.sharedApplication().statusBarHidden ? 0 : 20))
        
        self.reloadItems()
        
        self.tableViewController.refreshControl = UIRefreshControl()
        tableViewController.refreshControl?.addTarget(self, action: "reloadItems", forControlEvents: .ValueChanged)
        
        self.navigationItem.title = NSLocalizedString("Local Import", comment: "")
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Dismiss", comment: ""), style: .Plain, target: self, action: "dismiss")
        
        self.tableViewController.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableViewController.tableView.delegate = self
        self.tableViewController.tableView.dataSource = self
    }
    
    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        super.willRotateToInterfaceOrientation(toInterfaceOrientation, duration: duration)
        let landscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation)
        let statusBarHeight : CGFloat = (landscape ? 0 : 20)
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            let navBarHeight : CGFloat = (landscape ? 32 : 44)
            tableViewTopOffset.constant = navBarHeight + statusBarHeight
        } else {
            tableViewTopOffset.constant = 44 + statusBarHeight
        }
        UIView.animateWithDuration(duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func reloadItems() {
        let documents : String = NSHomeDirectory().stringByAppendingPathComponent("Documents")
        var error : NSError? = nil
        let contents = (NSFileManager.defaultManager().contentsOfDirectoryAtPath(documents, error: &error) as [String])
        for path in contents {
            verifyIfFeedOrOPML(path)
        }
        
        self.tableViewController.refreshControl?.endRefreshing()
    }
    
    func reload() {
        self.items.sort {return $0 < $1}
        self.tableViewController.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
    }
    
    func verifyIfFeedOrOPML(path: String) {
        if contains(contentsOfDirectory, path) {
            return;
        }
        
        contentsOfDirectory.append(path)
        
        let location = NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent(path)
        if let text = NSString(contentsOfFile: location, encoding: NSUTF8StringEncoding, error: nil) {
            let opmlParser = OPMLParser(text: text)
            let feedParser = FeedParser(string: text)
            feedParser.parseInfoOnly = true
            feedParser.completion = {(_, _) in
                self.items.append(path)
                self.feeds.append(path)
                opmlParser.stopParsing()
                self.reload()
            }
            opmlParser.callback = {(_) in
                self.items.append(path)
                self.opmls.append(path)
                feedParser.stopParsing()
                self.reload()
            }
            feedParser.parse()
            opmlParser.parse()
        }
    }
    
    // MARK: - Table view data source

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as UITableViewCell
        
        cell.textLabel?.text = items[indexPath.row]

        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        let item = items[indexPath.row]
        let location = NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent(item)
        if contains(feeds, item) {
            let location = NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent(item)
            let text = NSString(contentsOfFile: location, encoding: NSUTF8StringEncoding, error: nil)!
            let feedParser = FeedParser(string: text)
            feedParser.parseInfoOnly = true
            
            let activityIndicator = RBActivityIndicator(forAutoLayout: ())
            activityIndicator.showProgressBar = true
            activityIndicator.style = RBActivityIndicatorStyleDark
            activityIndicator.displayMessage = NSLocalizedString("Importing feed", comment: "")
            self.view.addSubview(activityIndicator)
            self.navigationItem.leftBarButtonItem?.enabled = false
            let color = activityIndicator.backgroundColor
            activityIndicator.backgroundColor = UIColor.clearColor()
            activityIndicator.autoCenterInSuperview()
            UIView.animateWithDuration(0.3, animations: {activityIndicator.backgroundColor = color})
            self.view.userInteractionEnabled = false
            
            feedParser.completion = {(info, _) in
                if let url = info.url.absoluteString {
                    self.dataManager.newFeed(info.url.absoluteString!) {(error) in
                        activityIndicator.removeFromSuperview()
                        self.view.userInteractionEnabled = true
                        self.navigationItem.leftBarButtonItem?.enabled = true
                        self.dismiss()
                    }
                } else {
                    activityIndicator.removeFromSuperview()
                    self.view.userInteractionEnabled = true
                    self.navigationItem.leftBarButtonItem?.enabled = true
                    self.dismiss()
                }
            }
        } else if contains(opmls, item) {
            
            let activityIndicator = RBActivityIndicator(forAutoLayout: ())
            activityIndicator.showProgressBar = true
            activityIndicator.style = RBActivityIndicatorStyleDark
            activityIndicator.displayMessage = NSLocalizedString("Importing feeds from OPML file", comment: "")
            self.view.addSubview(activityIndicator)
            self.navigationItem.leftBarButtonItem?.enabled = false
            let color = activityIndicator.backgroundColor
            activityIndicator.backgroundColor = UIColor.clearColor()
            activityIndicator.autoCenterInSuperview()
            UIView.animateWithDuration(0.3, animations: {activityIndicator.backgroundColor = color})
            self.view.userInteractionEnabled = false
            
            let dataManager = self.injector!.create(DataManager.self) as DataManager

            dataManager.importOPML(NSURL(string: "file://" + location)!, progress: {(progress: Double) in
                activityIndicator.progress = progress
            }) {(_) in
                self.dismiss()
                activityIndicator.removeFromSuperview()
                self.view.userInteractionEnabled = true
                self.navigationItem.leftBarButtonItem?.enabled = true
            }
        }
    }
}
