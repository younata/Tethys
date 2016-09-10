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

        it("binds the main operation queue to kMainQueue") {
            expect(injector.create(kMainQueue) as? NSOperationQueue).to(beIdenticalTo(NSOperationQueue.mainQueue()))
        }

        it("binds a single background queue") {
            expect(injector.create(kBackgroundQueue) as? NSObject).to(beIdenticalTo(injector.create(kBackgroundQueue) as? NSObject))
        }

        #if os(iOS)
            it("binds a searchIndex") {
                expect(injector.create(SearchIndex)! === CSSearchableIndex.defaultSearchableIndex()) == true
            }
        #endif

        it("binds a URLSession to the shared session") {
            let urlSession = injector.create(URLSession)
            expect(urlSession).toNot(beNil())

            expect(urlSession) === URLSession.sharedSession()
        }

        it("binds a DatabaseUseCase") {
            expect(injector.create(DatabaseUseCase.self) is DefaultDatabaseUseCase) == true
        }

        it("binds an opml manager with a singleton scope") {
            expect(injector.create(OPMLService)).to(beIdenticalTo(injector.create(OPMLService)))
        }
    }
}
