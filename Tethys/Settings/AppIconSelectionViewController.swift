import UIKit
import PureLayout

final class AppIconSelectionViewController: UIViewController {
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())

    private let appIconChanger: AppIconChanger

    init(appIconChanger: AppIconChanger) {
        self.appIconChanger = appIconChanger
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("SettingsViewController_AlternateIcons_Title", comment: "")

        self.collectionView.delegate = self
        self.collectionView.dataSource = self

        if let layout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            self.configure(layout: layout)
        }

        self.collectionView.backgroundColor = Theme.backgroundColor

        self.collectionView.register(ImageLabelCollectionViewCell.self, forCellWithReuseIdentifier: "cell")

        self.view.addSubview(self.collectionView)
        self.collectionView.autoPinEdgesToSuperviewEdges()

        guard let selectedRow = AppIcon.all.firstIndex(of: self.appIconChanger.selectedIcon) else { return }
        let indexPath = IndexPath(item: selectedRow, section: 0)

        self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }

    private func configure(layout: UICollectionViewFlowLayout) {
        layout.estimatedItemSize = CGSize(width: 84, height: 100)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    }
}

extension AppIconSelectionViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return AppIcon.all.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell",
                                                            for: indexPath) as? ImageLabelCollectionViewCell else {
            fatalError("Wrong cell type was dequeue'd")
        }
        let icon = self.icon(at: indexPath)

        cell.imageView.image = UIImage(named: icon.imageName)
        cell.label.text = icon.localizedName
        cell.accessibilityIdentifier = "AppIcon \(icon.accessibilityId)"
        cell.accessibilityLabel = icon.localizedName

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let icon = self.icon(at: indexPath)
        guard self.appIconChanger.selectedIcon != icon else { return }

        self.appIconChanger.selectedIcon = icon
    }

    private func icon(at indexPath: IndexPath) -> AppIcon {
        return AppIcon.all[indexPath.item]
    }
}

final class ImageLabelCollectionViewCell: UICollectionViewCell {
    let label = UILabel()
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        self.commonInit()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        self.label.text = nil
        self.imageView.image = nil
    }

    private func commonInit() {
        self.selectedBackgroundView = UIView(frame: self.bounds)
        self.selectedBackgroundView?.layer.cornerRadius = 4
        self.selectedBackgroundView?.layer.borderColor = Theme.highlightColor.cgColor
        self.selectedBackgroundView?.layer.borderWidth = 1
        self.selectedBackgroundView?.backgroundColor = Theme.overlappingBackgroundColor

        self.contentView.addSubview(self.label)
        self.contentView.addSubview(self.imageView)

        let inset = CGFloat(8)

        self.imageView.autoPinEdge(toSuperviewEdge: .top, withInset: inset)
        self.imageView.autoAlignAxis(toSuperviewAxis: .vertical)
        self.imageView.autoPinEdge(toSuperviewEdge: .leading, withInset: inset).priority = .defaultHigh
        self.imageView.autoPinEdge(toSuperviewEdge: .trailing, withInset: inset).priority = .defaultHigh

        self.imageView.layer.cornerRadius = 14
        self.imageView.layer.masksToBounds = true

        self.label.autoPinEdge(.top, to: .bottom, of: self.imageView, withOffset: 4)
        self.label.autoAlignAxis(toSuperviewAxis: .vertical)
        self.label.autoPinEdge(toSuperviewEdge: .leading, withInset: inset).priority = .defaultHigh
        self.label.autoPinEdge(toSuperviewEdge: .trailing, withInset: inset).priority = .defaultHigh
        self.label.autoPinEdge(toSuperviewEdge: .bottom, withInset: inset)

        self.layer.cornerRadius = 4

        self.label.textAlignment = .center
        self.label.textColor = Theme.textColor
    }
}
