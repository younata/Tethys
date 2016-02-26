import UIKit
import AVKit
import AVFoundation
import PureLayout
import rNewsKit

public class EnclosuresList: UIView, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    public private(set) var enclosures = DataStoreBackedArray<Enclosure>([]) {
        didSet {
            if let flowlayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                if enclosures.count == 1 {
                    flowlayout.estimatedItemSize = CGSize(width: 48, height: 50)
                } else {
                    flowlayout.estimatedItemSize = CGSize(width: 100, height: 80)
                }
            }
            self.collectionView.reloadData()
        }
    }

    public private(set) var viewControllerToPresentOn: UIViewController?
    public var themeRepository: ThemeRepository?
    public let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())

    private let cellIdentifier = "cell"


    public class EnclosureCell: UICollectionViewCell, ThemeRepositorySubscriber {
        public var thumbnail: UIImage? {
            didSet {
                self.imageView.image = thumbnail?.imageWithRenderingMode(.AlwaysTemplate)
            }
        }

        public var title: String? {
            didSet {
                self.label.text = title
            }
        }

        public func configure(title: String?, thumbnail: UIImage?, showTitle: Bool) {
            self.thumbnail = thumbnail
            if showTitle {
                self.label.hidden = false
                self.title = title
            } else {
                self.label.hidden = true
                self.title = nil
            }
        }

        private let imageView = UIImageView(forAutoLayout: ())
        private let label = UILabel(forAutoLayout: ())

        public override init(frame: CGRect) {
            super.init(frame: frame)
            self.imageView.tintColor = UIColor.darkGreenColor()
            self.imageView.contentMode = .Center
            self.label.lineBreakMode = .ByTruncatingMiddle
            self.label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)

            self.contentView.addSubview(self.imageView)
            self.contentView.addSubview(self.label)
            self.imageView.autoPinEdgeToSuperviewEdge(.Top)
            self.imageView.autoAlignAxisToSuperviewAxis(.Vertical)
            self.imageView.autoPinEdgeToSuperviewEdge(.Leading, withInset: 0, relation: .GreaterThanOrEqual)
            self.imageView.autoPinEdgeToSuperviewEdge(.Trailing, withInset: 0, relation: .GreaterThanOrEqual)
            self.imageView.autoPinEdge(.Bottom, toEdge: .Top, ofView: self.label)
            self.label.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        }

        public required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // swiftlint:disable line_length
        public override func preferredLayoutAttributesFittingAttributes(layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
            let attr: UICollectionViewLayoutAttributes = layoutAttributes.copy() as! UICollectionViewLayoutAttributes

            var newFrame = attr.frame
            self.frame = newFrame

            self.setNeedsLayout()
            self.layoutIfNeeded()

            let desiredHeight = self.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
            newFrame.size.height = desiredHeight
            attr.frame = newFrame
            return attr
        }
        // swiftlint:enable line_length

        public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
            self.label.textColor = themeRepository.textColor
        }
    }

    public func configure(enclosures: DataStoreBackedArray<Enclosure>, viewController: UIViewController) {
        self.enclosures = enclosures
        self.viewControllerToPresentOn = viewController
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.collectionView.registerClass(EnclosureCell.self, forCellWithReuseIdentifier: self.cellIdentifier)
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        if let flowlayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowlayout.estimatedItemSize = CGSize(width: 100, height: 80)
            flowlayout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        }

        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.backgroundColor = UIColor.clearColor()
        self.addSubview(self.collectionView)
        self.collectionView.autoPinEdgesToSuperviewEdges()
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
            cell.configure(self.enclosures[indexPath.item].url.lastPathComponent,
                thumbnail: UIImage(named: "podcast"),
                showTitle: self.enclosures.count > 1)
            self.themeRepository?.addSubscriber(cell)
            return cell
    }

    public func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let playerViewController = AVPlayerViewController()
        playerViewController.player = AVPlayer(URL: self.enclosures[indexPath.item].url)
        self.viewControllerToPresentOn?.presentViewController(playerViewController, animated: true, completion: nil)
    }
}
