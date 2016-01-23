import UIKit
import PureLayout
import rNewsKit

public class EnclosuresList: UIView, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    public var enclosures = DataStoreBackedArray<Enclosure>([]) {
        didSet {
            self.collectionView.reloadData()
        }
    }

    public let collectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: UICollectionViewFlowLayout())

    private let cellIdentifier = "cell"

    public class EnclosureCell: UICollectionViewCell {
        public var thumbnail: UIImage? {
            didSet {
                self.imageView.image = thumbnail
            }
        }

        private let imageView = UIImageView(forAutoLayout: ())

        public override init(frame: CGRect) {
            super.init(frame: frame)

            self.addSubview(self.imageView)
            self.imageView.tintColor = UIColor.darkGreenColor()
            self.imageView.autoPinEdgesToSuperviewEdges()
        }

        public required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.collectionView.registerClass(EnclosureCell.self, forCellWithReuseIdentifier: self.cellIdentifier)
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("")
    }

    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.enclosures.count
    }

    public func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
            let cell = self.collectionView.dequeueReusableCellWithReuseIdentifier(self.cellIdentifier,
                forIndexPath: indexPath) as! EnclosureCell
            cell.thumbnail = UIImage(named: "podcast")
            return cell
    }
}
