import Quick
import Nimble
import UIKit
@testable import Tethys

final class AppIconSelectionViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: AppIconSelectionViewController!

        var appIconChanger: FakeAppIconChanger!

        beforeEach {
            appIconChanger = FakeAppIconChanger()

            subject = AppIconSelectionViewController(appIconChanger: appIconChanger)

            subject.view.layoutIfNeeded()
        }

        it("sets the title of the nav bar") {
            expect(subject.title).to(equal("App Icon"))
        }

        describe("the collection view") {
            it("shows everything in a single section") {
                expect(subject.collectionView.numberOfSections).to(equal(1))
            }

            it("displays an item for each possible app icon") {
                expect(subject.collectionView.numberOfItems(inSection: 0)).to(equal(2))
                expect(AppIcon.all).to(haveCount(2))
            }

            describe("the first cell") {
                var cell: ImageLabelCollectionViewCell?
                let indexPath = IndexPath(item: 0, section: 0)

                beforeEach {
                    cell = subject.collectionView.cellForItem(at: indexPath) as? ImageLabelCollectionViewCell
                }

                it("is already set as selected") {
                    expect(subject.collectionView.indexPathsForSelectedItems).to(equal([indexPath]))
                }

                it("shows primary icon logo") {
                    expect(cell?.imageView.image).to(equal(UIImage(named: "DefaultAppIcon")))
                }

                it("labels the logo") {
                    expect(cell?.label.text).to(equal("White"))
                }

                describe("when selected") {
                    beforeEach {
                        subject.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                        subject.collectionView.delegate?.collectionView?(subject.collectionView, didSelectItemAt: indexPath)
                    }

                    it("does not try to change the app icon") {
                        expect(appIconChanger.setAlternateIconCalls).to(beEmpty())
                    }
                }
            }

            describe("the second cell") {
                var cell: ImageLabelCollectionViewCell?
                let indexPath = IndexPath(item: 1, section: 0)

                beforeEach {
                    cell = subject.collectionView.cellForItem(at: indexPath) as? ImageLabelCollectionViewCell
                }

                it("shows primary icon logo") {
                    expect(cell?.imageView.image).to(equal(UIImage(named: "BlackAppIcon")))
                }

                it("labels the logo") {
                    expect(cell?.label.text).to(equal("Black"))
                }

                describe("when selected") {
                    beforeEach {
                        subject.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                        subject.collectionView.delegate?.collectionView?(subject.collectionView, didSelectItemAt: indexPath)
                    }

                    it("does not try to change the app icon") {
                        expect(appIconChanger.setAlternateIconCalls).to(haveCount(1))

                        expect(appIconChanger.setAlternateIconCalls.last?.name).to(equal("AppIcon-Black"))
                    }
                }
            }
        }
    }
}
