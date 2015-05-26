import UIKit

class EnclosuresView: UIView, UICollectionViewDelegate, UICollectionViewDataSource {
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = CGSizeMake(68, 98)

        let view = UICollectionView(frame: CGRectZero, collectionViewLayout: layout)
        view.setTranslatesAutoresizingMaskIntoConstraints(false)
        view.registerClass(EnclosureCell.self, forCellWithReuseIdentifier: "cell")
        view.backgroundColor = UIColor.clearColor()

        view.delegate = self
        view.dataSource = self

        self.addSubview(view)
        view.setTranslatesAutoresizingMaskIntoConstraints(false)
        view.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        return view
    }()

    var dataManager: DataManager? = nil

    var openEnclosure: (CoreDataEnclosure) -> (Void) = {(_) in }

    var enclosures: [CoreDataEnclosure]? = nil {
        didSet {
            collectionView.reloadData()
        }
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

    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell",
                forIndexPath: indexPath) as! EnclosureCell
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
                    let cell = (collectionView.visibleCells() as? [EnclosureCell])?.filter({
                        return $0.enclosure?.objectID == enclosure.objectID
                    }).first
                    cell?.progressLayer.progress = progress
                }) {(_, error) in
                    let cell = (collectionView.visibleCells() as? [EnclosureCell])?.filter({
                        return $0.enclosure?.objectID == enclosure.objectID
                    }).first
                    cell?.progressLayer.progress = 0
                }
            }
        }
    }
}
