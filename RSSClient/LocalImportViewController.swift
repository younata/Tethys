//
//  LocalImportViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/14/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class LocalImportViewController: UITableViewController, MWFeedParserDelegate {
    
    var opmls : [String] = []
    var feeds : [String] = []
    var items : [String] = []
    var contentsOfDirectory : [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.reloadItems()
        
        self.refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: "reloadItems", forControlEvents: .ValueChanged)
    }
    
    func reloadItems() {
        let documents : String = NSHomeDirectory().stringByAppendingPathComponent("Documents")
        var error : NSError? = nil
        let contents = (NSFileManager.defaultManager().contentsOfDirectoryAtPath(documents, error: &error) as [String])
        for path in contents {
            verifyIfFeedOrOPML(path)
        }
        
        self.refreshControl?.endRefreshing()
    }
    
    func reload() {
        self.items.sort {return $0 < $1}
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
    }
    
    func verifyIfFeedOrOPML(path: String) {
        if contains(contentsOfDirectory, path) {
            return;
        }
        
        contentsOfDirectory.append(path)
        
        let location = NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent(path)
        let text = NSString(contentsOfFile: location, encoding: NSUTF8StringEncoding, error: nil)!
        
        let opmlParser = OPMLParser(text: text)
        let feedParser = FeedParser(string: text)
        feedParser.parseInfoOnly = true
        opmlParser.callback = {(_) in
            self.items.append(path)
            self.opmls.append(path)
            feedParser.stopParsing()
            self.reload()
        }
        feedParser.completion = {(_, _) in
            self.items.append(path)
            self.feeds.append(path)
            opmlParser.stopParsing()
            self.reload()
        }
        opmlParser.parse()
        feedParser.parse()
    }
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as UITableViewCell
        
        cell.textLabel.text = items[indexPath.row]

        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        let item = items[indexPath.row]
        let location = NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent(item)
        if contains(feeds, item) {
            let location = NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent(item)
            let text = NSString(contentsOfFile: location, encoding: NSUTF8StringEncoding, error: nil)!
            let feedParser = FeedParser(string: text)
            feedParser.parseInfoOnly = true
            feedParser.completion = {(info, _) in
                print("")
                DataManager.sharedInstance().newFeed(info.url.absoluteString!)
            }
        } else if contains(opmls, item) {
            DataManager.sharedInstance().importOPML(NSURL(string: "file://" + location)!)
        }
    }
}
