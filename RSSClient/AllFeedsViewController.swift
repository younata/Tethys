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
        
        //self.view.addSubview(refreshControl)
        //self.refreshControl.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)

        // Register cell classes
        self.collectionView.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.collectionView.registerClass(FeedCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        self.collectionView.backgroundColor = UIColor.whiteColor()
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.layout.estimatedItemSize = CGSizeMake(120, 40)
        // Do any additional setup after loading the view.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "refresh", name: "UpdatedFeed", object: nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        self.refresh()
    }

    func refresh() {
        feeds = DataManager.sharedInstance().feeds()
        //self.refreshControl.endRefreshing()
        self.collectionView.reloadSections(NSIndexSet(index: 0))
    }
    
    func addFeed() {
        if (self.navigationController!.visibleViewController != self) {
            return
        }
        let vc = UINavigationController(rootViewController: FindFeedViewController())
        self.presentViewController(vc, animated: true, completion: nil)
    }
    
    func deleteCell(cell: FeedCell) {
        self.deleteFeed(feeds[self.collectionView.indexPathForCell(cell)!.row])
    }
    
    func deleteFeed(feed: Feed) {
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
        
        cell.configure()
        
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
