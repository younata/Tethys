import Quick
import Nimble
import rNews
import rNewsKit

class EnclosuresListSpec: QuickSpec {
    override func spec() {
        let enclosure1 = Enclosure(url: NSURL(string: "https://example.com/podcast.mp3")!, kind: "audio/mpeg", article: nil)
        let enclosure2 = Enclosure(url: NSURL(string: "https://example.com/podcast.aac")!, kind: "audio/aac", article: nil)

        var subject: EnclosuresList!

        beforeEach {
            subject = EnclosuresList(frame: CGRectZero)

            subject.enclosures = DataStoreBackedArray([enclosure1, enclosure2])
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
                subject.enclosures = DataStoreBackedArray([enclosure1])

                guard let cell = subject.collectionView.dataSource?.collectionView(subject.collectionView,
                    cellForItemAtIndexPath: indexPath) as? EnclosuresList.EnclosureCell else { fail("no"); return }

                expect(cell.thumbnail) == UIImage(named: "podcast")
                expect(cell.title).to(beNil())
            }
        }
    }
}
