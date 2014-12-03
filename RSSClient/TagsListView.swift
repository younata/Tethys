//
//  TagsListView.swift
//  RSSClient
//
//  Created by Rachel Brindle on 12/2/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit



class TagsListView: UIView, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    var tags : [String]? = nil {
        didSet {
            self.collectionView.reloadData()
        }
    }
    
    let collectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: UICollectionViewFlowLayout())
    
    var allowEditing : Bool = false

    var didSelectTag: (String) -> Void = {(_) in }
    
    var layout: UICollectionViewFlowLayout {
        get { return collectionView.collectionViewLayout as UICollectionViewFlowLayout }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("coding not supported")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        collectionView.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.addSubview(collectionView)
        collectionView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.registerClass(TagCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        let layout = collectionView.collectionViewLayout as UICollectionViewFlowLayout
        layout.estimatedItemSize = CGSizeMake(100, 32)
        collectionView.backgroundColor = UIColor.whiteColor()
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tags?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath) as TagCollectionViewCell
        
        cell.layer.borderColor = UIColor.blackColor().CGColor
        cell.layer.borderWidth = 1
        cell.backgroundColor = UIColor.whiteColor()
        cell.label.text = tags?[indexPath.row]
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        collectionView.deselectItemAtIndexPath(indexPath, animated: false)
        
        if let tag = tags?[indexPath.row] {
            self.didSelectTag(tag)
        }
    }
    
    func collectionView(collectionView: UICollectionView, shouldShowMenuForItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return allowEditing
    }
}
