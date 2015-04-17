//
//  EnclosuresView.swift
//  RSSClient
//
//  Created by Rachel Brindle on 12/4/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class EnclosuresView: UIView, UICollectionViewDelegate, UICollectionViewDataSource {
    let collectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: UICollectionViewFlowLayout())
    
    var dataManager : DataManager? = nil
    
    var openEnclosure : (Enclosure) -> (Void) = {(_) in }
    
    var enclosures : [Enclosure]? = nil {
        didSet {
            collectionView.reloadData()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.addSubview(collectionView)
        collectionView.setTranslatesAutoresizingMaskIntoConstraints(false)
        collectionView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        collectionView.registerClass(EnclosureCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.backgroundColor = UIColor.clearColor()
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.estimatedItemSize = CGSizeMake(68, 98)
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let enc = enclosures {
            return enc.count
        }
        return 0
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath) as! EnclosureCell
        cell.enclosure = enclosures?[indexPath.row]
        if let enclosure = enclosures?[indexPath.row] {
            if let progress = dataManager?.progressForEnclosure(enclosure) {
                cell.progressLayer.progress = (progress == -1 ? 0 : progress)
            }
        }
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        collectionView.deselectItemAtIndexPath(indexPath, animated: false)
        
        let enclosure = enclosures![indexPath.row]
        if enclosure.data != nil {
            openEnclosure(enclosure)
        } else {
            if let progress = dataManager?.progressForEnclosure(enclosure) where progress == -1 {
                dataManager?.downloadEnclosure(enclosure, progress: {(progress) in
                    if let cell = (collectionView.visibleCells() as! [EnclosureCell]).filter({return $0.enclosure?.objectID == enclosure.objectID}).first {
                        cell.progressLayer.progress = progress
                    }
                }) {(_, error) in
                    if let cell = (collectionView.visibleCells() as! [EnclosureCell]).filter({return $0.enclosure?.objectID == enclosure.objectID}).first {
                        cell.progressLayer.progress = 0
                    }
                }
            } else {
                // nothing!
            }
        }
    }
}
