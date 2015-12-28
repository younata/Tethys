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

        it("should bind the shared URLSession to NSURLSession") {
            expect(injector.create(NSURLSession)).to(beIdenticalTo(NSURLSession.sharedSession()))
        }

        #if os(iOS)
            if #available(iOS 9.0, *) {
                it("should, on iOS 9, bind a searchIndex") {
                    expect(injector.create(SearchIndex)! === CSSearchableIndex.defaultSearchableIndex()).to(beTruthy())
                }
            }
        #endif

        it("should bind the DataService to a CoreDataService") {
            expect(injector.create(DataService) is CoreDataService) == true
        }

        it("should bind a DataRetriever") {
            expect(injector.create(DataRetriever.self) is DataRepository).to(beTruthy())
        }

        it("should bind a DataWriter") {
            expect(injector.create(DataWriter.self) is DataRepository).to(beTruthy())
        }

        it("should bind an opml manager with a singleton scope") {
            expect(injector.create(OPMLManager)).to(beIdenticalTo(injector.create(OPMLManager)))
        }
    }
}
