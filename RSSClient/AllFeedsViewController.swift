//
//  AllFedsViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

let reuseIdentifier = "Cell"

class AllFeedsViewController: UICollectionViewController {
    
    let refreshControl = UIRefreshControl(frame: CGRectZero)
    
    var feeds: [Feed] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = NSLocalizedString("Feeds", comment: "")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "+", style: .Plain, target: self, action: "addFeed")
        
        self.view.addSubview(refreshControl)
        self.refreshControl.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)

        // Register cell classes
        self.collectionView!.registerClass(FeedCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        // Do any additional setup after loading the view.
        self.refresh()
    }

    func refresh() {
        feeds = DataManager.sharedInstance().feeds()
        self.refreshControl.endRefreshing()
        self.collectionView!.reloadSections(NSIndexSet(index: 0))
    }
    
    func addFeed() {
        if (self.navigationController!.visibleViewController != self) {
            return
        }
        let vc = UIViewController()
        self.presentViewController(vc, animated: true, completion: nil)
    }
    
    func deleteCell(cell: FeedCell) {
        if let cv = self.collectionView {
            self.deleteFeed(feeds[cv.indexPathForCell(cell)!.row])
        }
    }
    
    func deleteFeed(feed: Feed) {
        self.refresh()
    }
    
    func showFeedFromCell(cell: FeedCell) {
        if let cv = self.collectionView {
            self.showFeed(feeds[cv.indexPathForCell(cell)!.row])
        }
    }
    
    func showFeed(feed: Feed) {
        
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return feeds.count
    }

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as FeedCell
        
        cell.configure()
        
        let feed : Feed = feeds[indexPath.row]
        cell.image = (feed.image as UIImage)
        cell.title = feed.title
        cell.summary = feed.summary
        cell.link = NSURL(string: feed.url)
        
        return cell
    }

    // MARK: UICollectionViewDelegate
    
    override func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
    }
}
