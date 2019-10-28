import Quick
import Nimble

@testable import Tethys

final class EasterEggGalleryViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: EasterEggGalleryViewController!

        var easterEggVC1: UIViewController!
        var easterEggVC2: UIViewController!

        let easterEggs = [
            EasterEgg(name: "test 1", image: UIImage(named: "GrayIcon")!, viewController: { easterEggVC1 }),
            EasterEgg(name: "test 2", image: UIImage(named: "Checkmark")!, viewController: { easterEggVC2 })
        ]

        beforeEach {
            easterEggVC1 = UIViewController()
            easterEggVC2 = UIViewController()

            subject = EasterEggGalleryViewController(easterEggs: easterEggs)

            subject.view.layoutIfNeeded()
        }

        it("titles itself") {
            expect(subject.title).to(equal("Easter Eggs"))
        }

        describe("the collection view") {
            it("has an item for each easter egg") {
                expect(subject.collectionView.numberOfSections).to(equal(1))
                expect(subject.collectionView.numberOfItems(inSection: 0)).to(equal(easterEggs.count))
            }

            it("is configured with the theme") {
                expect(subject.collectionView.backgroundColor).to(equal(Theme.backgroundColor))
                expect(subject.view.backgroundColor).to(equal(Theme.backgroundColor))
            }

            describe("a cell") {
                var cell: CollectionViewCell?

                let indexPath = IndexPath(item: 0, section: 0)

                beforeEach {
                    guard subject.collectionView.numberOfSections == 1,
                        subject.collectionView.numberOfItems(inSection: 0) == easterEggs.count else {
                            return
                    }
                    cell = subject.collectionView.cellForItem(at: indexPath) as? CollectionViewCell
                }

                it("displays information about the easter egg") {
                    expect(cell?.imageView.image).to(equal(UIImage(named: "GrayIcon")))
                    expect(cell?.label.text).to(equal("test 1"))
                }

                it("is themed properly") {
                    expect(cell?.label.textColor).to(equal(Theme.textColor))
                    expect(cell?.backgroundColor).to(equal(Theme.overlappingBackgroundColor))
                    expect(cell?.layer.cornerRadius).to(equal(4))
                }

                it("is configured for accessibility") {
                    expect(cell?.accessibilityLabel).to(equal("test 1"))
                    expect(cell?.accessibilityTraits).to(equal([.button]))
                }
            }

            describe("selecting a cell") {
                let indexPath = IndexPath(item: 0, section: 0)

                beforeEach {
                    subject.collectionView.delegate?.collectionView?(subject.collectionView, didSelectItemAt: indexPath)
                }

                it("presents the easter egg's view controller") {
                    expect(subject.presentedViewController).to(equal(easterEggVC1))
                    expect(subject.presentedViewController?.modalPresentationStyle).to(equal(.fullScreen))
                }
            }
        }
    }
}
