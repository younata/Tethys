import UIKit
import PureLayout

struct EasterEgg: Equatable {
    let name: String
    let image: UIImage
    let viewController: () -> UIViewController

    static func == (lhs: EasterEgg, rhs: EasterEgg) -> Bool {
        guard lhs.name == rhs.name && lhs.image == rhs.image else {
            return false
        }
        return lhs.viewController().classForCoder == rhs.viewController().classForCoder
    }
}

final class EasterEggGalleryViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    let easterEggs: [EasterEgg]

    private let collectionViewLayout = UICollectionViewFlowLayout()
    private(set) lazy var collectionView: UICollectionView = {
        let collectionView =  UICollectionView(frame: .zero, collectionViewLayout: self.collectionViewLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    init(easterEggs: [EasterEgg]) {
        self.easterEggs = easterEggs

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.collectionView)
        self.collectionView.autoPinEdgesToSuperviewSafeArea()

        self.title = NSLocalizedString("EasterEgg_Gallery_Title", comment: "")

        self.collectionView.dataSource = self
        self.collectionView.delegate = self

        self.collectionView.register(CollectionViewCell.self, forCellWithReuseIdentifier: "cell")

        self.collectionView.backgroundColor = Theme.backgroundColor
        self.view.backgroundColor = Theme.backgroundColor

        self.collectionViewLayout.itemSize = UICollectionViewFlowLayout.automaticSize
        self.collectionViewLayout.estimatedItemSize = CGSize(width: 250, height: 300)
        self.collectionViewLayout.minimumLineSpacing = 8
        self.collectionViewLayout.minimumInteritemSpacing = 8
        self.collectionViewLayout.sectionInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.easterEggs.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let collectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        guard let cell = collectionViewCell as? CollectionViewCell else {
            return collectionViewCell
        }

        let easterEgg = self.easterEggs[indexPath.item]
        cell.imageView.image = easterEgg.image
        cell.label.text = easterEgg.name
        cell.accessibilityLabel = easterEgg.name
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let easterEgg = self.easterEggs[indexPath.item]

        let viewController = easterEgg.viewController()
        viewController.modalPresentationStyle = .fullScreen
        self.present(viewController, animated: true, completion: nil)
    }
}

final class CollectionViewCell: UICollectionViewCell {
    let imageView = UIImageView()
    let label = UILabel()

    override func prepareForReuse() {
        super.prepareForReuse()

        self.imageView.image = nil
        self.label.text = nil
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.contentView.addSubview(self.imageView)
        self.contentView.addSubview(self.label)

        self.imageView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        self.label.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.label.autoPinEdge(.top, to: .bottom, of: self.imageView, withOffset: 8)
        self.label.textAlignment = .center
        self.label.font = UIFont.preferredFont(forTextStyle: .title1)

        self.backgroundColor = Theme.overlappingBackgroundColor
        self.layer.cornerRadius = 4
        self.layer.masksToBounds = true

        self.accessibilityTraits = [.button]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
