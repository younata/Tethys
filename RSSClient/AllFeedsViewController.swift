//
//  AllFedsViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

let reuseIdentifier = "Cell"

class AllFeedsViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    //let refreshControl = UIRefreshControl(frame: CGRectZero)
    let collectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: UICollectionViewFlowLayout())
    var layout : UICollectionViewFlowLayout {
        return (self.collectionView.collectionViewLayout as UICollectionViewFlowLayout)
    }
    
    var feeds: [Feed] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = NSLocalizedString("Feeds", comment: "")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .Plain, target: self, action: "addFeed")
        
        // Register cell classes
        self.view.addSubview(self.collectionView)
        self.collectionView.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.collectionView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(0, 0, 0, 0))
        self.collectionView.registerClass(FeedCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        self.collectionView.backgroundColor = UIColor.whiteColor()
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.layout.sectionInset = UIEdgeInsetsMake(0, 10, 0, 10)
        self.layout.estimatedItemSize = CGSizeMake(120, 40)
        // Do any additional setup after loading the view.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "refresh", name: "UpdatedFeed", object: nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        self.refresh()
    }

    func refresh() {
        feeds = DataManager.sharedInstance().feeds()
        self.collectionView.reloadSections(NSIndexSet(index: 0))
    }
    
    func addFeed() {
        if (self.navigationController!.visibleViewController != self) {
            return
        }
        
        /*
        class FeedHandler: NSObject, UITextFieldDelegate, MWFeedParserDelegate {
            var parser: MWFeedParser? = nil
            var textField: UITextField? = nil
            
            var onValidFeed: () -> (Void) = {}
            var onInvalidFeed: () -> (Void) = {}
            
            func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
                var text = NSString(string: textField.text).stringByReplacingCharactersInRange(range, withString: string)
                if (text.rangeOfString("://") != nil) {
                    text = text + "http://"
                }
                if let p = parser {
                    p.stopParsing()
                }
                parser = MWFeedParser(feedURL: NSURL(string: text))
                parser!.feedParseType = ParseTypeInfoOnly
                parser!.connectionType = ConnectionTypeAsynchronously
                parser!.delegate = self
                parser!.parse()
                return true
            }
            
            func feedParser(parser: MWFeedParser!, didParseFeedInfo info: MWFeedInfo!) {
                onValidFeed()
                self.parser = nil
            }
            
            func feedParser(parser: MWFeedParser!, didFailWithError error: NSError!) {
                onInvalidFeed()
                self.parser = nil
            }
        }
        
        let alert = UIAlertController(title: NSLocalizedString("Enter Feed URL", comment: ""), message: NSLocalizedString("http:// will be auto-prepended if not otherwise specified", comment: ""), preferredStyle: .Alert)
        alert.addTextFieldWithConfigurationHandler({(textField: UITextField!) in
            textField.placeholder = NSLocalizedString("Feed URL", comment: "")
            /*
            let handler = FeedHandler()
            handler.textField = textField
            handler.onValidFeed = {
                textField.textColor = UIColor.darkTextColor()
            }
            handler.onInvalidFeed = {
                textField.textColor = UIColor.redColor()
            }
            textField.delegate = handler
*/
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel, handler: {(action: UIAlertAction!) in
            alert.presentingViewController!.dismissViewControllerAnimated(true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Add", comment: ""), style: .Default, handler: {(action: UIAlertAction!) in
            var text : String = (alert.textFields?.first! as UITextField).text
            if (text.rangeOfString("://") != nil) {
                text = text + "http://"
            }
            let handler = FeedHandler()
            handler.onValidFeed = {
                DataManager.sharedInstance().newFeed(text, withICO: nil)
                alert.presentingViewController!.dismissViewControllerAnimated(true, completion: nil)
            }
            handler.onInvalidFeed = {
                alert.message = NSLocalizedString("Invalid Feed", comment: "")
            }
        }))
        */
        let vc = UINavigationController(rootViewController: FindFeedViewController())
        self.presentViewController(vc, animated: true, completion: nil)
    }
    
    func deleteCell(cell: FeedCell) {
        self.deleteFeed(feeds[self.collectionView.indexPathForCell(cell)!.row])
    }
    
    func deleteFeed(feed: Feed) {
        DataManager.sharedInstance().deleteFeed(feed)
        self.refresh()
    }
    
    func showFeedFromCell(cell: FeedCell) {
        self.showFeed(feeds[collectionView.indexPathForCell(cell)!.row])
    }
    
    func showFeed(feed: Feed) {
        let articleController = ArticleListController(style: .Plain)
        articleController.feeds = [feed]
        self.navigationController!.pushViewController(articleController, animated: true)
    }

    // MARK: UICollectionViewDataSource

    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }


    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return feeds.count
    }

    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as FeedCell
                
        let feed : Feed = feeds[indexPath.row]
        if let image = feed.image as? UIImage {
            cell.image = image
        }
        if let t = feed.title {
            cell.title = t
        }
        if let s = feed.summary {
            cell.summary = s
        }
        cell.link = NSURL(string: feed.url)
        cell.controller = self
        
        return cell
    }

    // MARK: UICollectionViewDelegate
    
    func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        self.showFeed(feeds[indexPath.row])
    }
}
