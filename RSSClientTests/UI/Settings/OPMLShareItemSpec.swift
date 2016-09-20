import Quick
import Nimble
import rNews
import rNewsKit
import Ra
import CBGPromise
import Result

class OPMLShareItemSpec: QuickSpec {
    override func spec() {
        var subject: OPMLShareItem!

        var opmlService: FakeOPMLService!

        beforeEach {
            let injector = Injector()

            opmlService = FakeOPMLService()
            injector.bind(kind: OPMLService.self, toInstance: opmlService)

            subject = injector.create(kind: OPMLShareItem.self)!
        }

        it("makes a request for the user's opmls") {
            expect(opmlService.didReceiveWriteOPML) == true
        }

        describe("if the request succeeds") {
            beforeEach {
                opmlService.writeOPMLPromises.last?.resolve(.success("hello"))
            }

            it("returns the string as data") {
                let data = "hello".data(using: String.Encoding.utf8)
                expect(subject.item as? Data) == data
            }
        }

        describe("if the request fails") {
            beforeEach {
                opmlService.writeOPMLPromises.last?.resolve(.failure(.unknown))
            }
            it("returns nil for the item property") {
                expect(subject.item as? Data) == Data()
            }
        }

        describe("as a UIActivityItemSource") {
            it("-activityViewController:dataTypeIdentifierForActivityType: returns opml") {
                expect(subject.activityViewController(UIActivityViewController(activityItems: [], applicationActivities: nil),
                                                      dataTypeIdentifierForActivityType: nil)) == "com.rachelbrindle.rssclient.opml"
            }

            it("-activityViewController:dataTypeIdentifierForActivityType: returns OPML Export") {
                expect(subject.activityViewController(UIActivityViewController(activityItems: [], applicationActivities: nil),
                                                      subjectForActivityType: nil)) == "OPML Export"
            }
        }
    }
}
