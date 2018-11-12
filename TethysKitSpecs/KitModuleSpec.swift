import Quick
import Nimble
import Swinject
#if os(iOS)
    import CoreSpotlight
#endif
@testable import TethysKit

class KitModuleSpec: QuickSpec {
    override func spec() {
        var subject: Container! = nil

        beforeEach {
            subject = Container()
            TethysKit.configure(container: subject)
        }

        it("binds the main operation queue to kMainQueue") {
            expect(subject.resolve(OperationQueue.self, name: kMainQueue)).to(beIdenticalTo(OperationQueue.main))
        }

        it("binds a single background queue") {
            expect(subject.resolve(OperationQueue.self, name: kBackgroundQueue)).to(beIdenticalTo(subject.resolve(OperationQueue.self, name: kBackgroundQueue)))
        }

        describe("Services") {
            exists(Bundle.self)
            exists(UserDefaults.self)
            exists(FileManager.self)

            alwaysIs(URLSession.self, a: URLSession.shared)
            #if os(iOS)
                exists(SearchIndex.self)
            #endif
            isA(DatabaseUseCase.self, kindOf: DefaultDatabaseUseCase.self, singleton: true)
            singleton(OPMLService.self)
            exists(BackgroundStateMonitor.self)
        }

        func exists<T>(_ type: T.Type) {
            describe(Mirror(reflecting: type).description) {
                it("exists") {
                    expect(subject.resolve(type)).toNot(beNil())
                }
            }
        }

        func singleton<T>(_ type: T.Type) {
            describe(Mirror(reflecting: type).description) {
                it("exists") {
                    expect(subject.resolve(type)).toNot(beNil())
                }

                it("is a singleton") {
                    expect(subject.resolve(type)).to(beIdenticalTo(subject.resolve(type)))
                }
            }
        }

        func isA<T, U>(_ type: T.Type, kindOf otherType: U.Type, singleton: Bool = false) {
            describe(Mirror(reflecting: type).description) {
                it("exists") {
                    expect(subject.resolve(type)).toNot(beNil())
                }

                it("is a \(Mirror(reflecting: otherType).description)") {
                    expect(subject.resolve(type)).to(beAKindOf(otherType))
                }

                if singleton {
                    it("is a singleton") {
                        expect(subject.resolve(type)).to(beIdenticalTo(subject.resolve(type)))
                    }
                }
            }
        }

        func alwaysIs<T: Equatable>(_ type: T.Type, a obj: T) {
            describe(Mirror(reflecting: type).description) {
                it("exists") {
                    expect(subject.resolve(type)).toNot(beNil())
                }

                it("is always \(Mirror(reflecting: obj).description)") {
                    expect(subject.resolve(type)).to(equal(obj))
                }
            }
        }
    }
}
