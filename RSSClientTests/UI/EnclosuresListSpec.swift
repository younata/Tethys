import Quick
import Nimble
import AVKit
import AVFoundation
import UIKit
import rNews
import rNewsKit

class EnclosuresListSpec: QuickSpec {
    override func spec() {
        let enclosure1 = Enclosure(url: NSURL(string: "https://example.com/podcast.mp3")!, kind: "audio/mpeg", article: nil)
        let enclosure2 = Enclosure(url: NSURL(string: "https://example.com/podcast.aac")!, kind: "audio/aac", article: nil)

        var subject: EnclosuresList!

        var viewController: UIViewController!

        beforeEach {
            subject = EnclosuresList(frame: CGRectZero)

            viewController = UIViewController()
            let enclosures = DataStoreBackedArray([enclosure1, enclosure2])
            subject.configure(enclosures, viewController: viewController)
        }

        it("should have one section") {
            expect(subject.collectionView.numberOfSections()) == 1
        }

        it("should display all the enclosures") {
            let numberOfCells = subject.collectionView.dataSource?.collectionView(subject.collectionView,
                numberOfItemsInSection: 0)

            expect(numberOfCells) == 2
        }

        describe("the cells") {
            let indexPath = NSIndexPath(forItem: 0, inSection: 0)

            it("displays each cell with an image describing it") {
                guard let cell = subject.collectionView.dataSource?.collectionView(subject.collectionView,
                    cellForItemAtIndexPath: indexPath) as? EnclosuresList.EnclosureCell else { fail("no"); return }

                expect(cell.thumbnail) == UIImage(named: "podcast")
                expect(cell.title) == "podcast.mp3"
            }

            it("does not display the title if the enclosure list only has 1 enclosure") {
                subject.configure(DataStoreBackedArray([enclosure1]), viewController: viewController)

                guard let cell = subject.collectionView.dataSource?.collectionView(subject.collectionView,
                    cellForItemAtIndexPath: indexPath) as? EnclosuresList.EnclosureCell else { fail("no"); return }

                expect(cell.thumbnail) == UIImage(named: "podcast")
                expect(cell.title).to(beNil())
            }

            it("present an AVPlayerViewController configured with the enclosure onto the view controller when tapped") {
                subject.collectionView.delegate?.collectionView?(subject.collectionView,
                    didSelectItemAtIndexPath: indexPath)

                expect(viewController.presentedViewController).to(beAKindOf(AVPlayerViewController.self))
                if let playerViewController = viewController.presentedViewController as? AVPlayerViewController {
                    expect(playerViewController.player).toNot(beNil())
                    expect(playerViewController.player?.currentItem).toNot(beNil())
                    expect(playerViewController.player?.currentItem?.asset).to(beAKindOf(AVURLAsset.self))
                    expect((playerViewController.player?.currentItem?.asset as? AVURLAsset)?.URL).to(equal(enclosure1.url))
                }
            }
        }
    }
}
