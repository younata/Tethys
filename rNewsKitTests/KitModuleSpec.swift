import Quick
import Nimble
import Ra
#if os(iOS)
    import CoreSpotlight
#endif
@testable import rNewsKit

class KitModuleSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil

        beforeEach {
            injector = Injector(module: KitModule())
        }

        it("should bind the main operation queue to kMainQueue") {
            expect(injector.create(kMainQueue) as? NSOperationQueue).to(beIdenticalTo(NSOperationQueue.mainQueue()))
        }

        it("should bind a single background queue") {
            expect(injector.create(kBackgroundQueue) as? NSObject).to(beIdenticalTo(injector.create(kBackgroundQueue) as? NSObject))
        }

        #if os(iOS)
            if #available(iOS 9.0, *) {
                it("should, on iOS 9, bind a searchIndex") {
                    expect(injector.create(SearchIndex)! === CSSearchableIndex.defaultSearchableIndex()) == true
                }
            }
        #endif

        it("should bind a URLSession to the shared session") {
            let urlSession = injector.create(NSURLSession)
            expect(urlSession).toNot(beNil())

            expect(urlSession) === NSURLSession.sharedSession()
        }

        it("should bind a DatabaseUseCase") {
            expect(injector.create(DatabaseUseCase.self) is DefaultDatabaseUseCase) == true
        }

        it("should bind an opml manager with a singleton scope") {
            expect(injector.create(OPMLService)).to(beIdenticalTo(injector.create(OPMLService)))
        }
    }
}
