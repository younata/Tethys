import Quick
import Nimble
import Swinject

import TethysKit
@testable import Tethys

final class InjectorModuleSpec: QuickSpec {
    override func spec() {
        var subject: Container!

        beforeEach {
            subject = Container()

            TethysKit.configure(container: subject)
            Tethys.configure(container: subject)
        }

        describe("services") {
            alwaysIs(UserDefaults.self, a: UserDefaults.standard)
        }

        describe("Repositories") {
            singleton(SettingsRepository.self)
            singleton(ThemeRepository.self)
            singleton(QuickActionRepository.self)
        }

        describe("Controllers") {
            isA(ArticleUseCase.self, kindOf: DefaultArticleUseCase.self)
            isA(DocumentationUseCase.self, kindOf: DefaultDocumentationUseCase.self)

            describe("Bootstrapper") {
                var bootstrapper: Bootstrapper?

                beforeEach {
                    let window = UIWindow(frame: CGRect.zero)
                    let splitController = SplitViewController(themeRepository: ThemeRepository(userDefaults: nil))
                    bootstrapper = subject.resolve(Bootstrapper.self, arguments: window, splitController)
                }

                it("exists") {
                    expect(bootstrapper).toNot(beNil())
                }

                it("is a BootstrapWorkFlow") {
                    expect(bootstrapper).to(beAKindOf(BootstrapWorkFlow.self))
                }
            }

            describe("ArticleCellController") {
                it("requires a bool argument") {
                    expect(subject.resolve(ArticleCellController.self)).to(beNil())
                    expect(subject.resolve(ArticleCellController.self, argument: false)).to(beAKindOf(DefaultArticleCellController.self))
                    expect(subject.resolve(ArticleCellController.self, argument: true)).to(beAKindOf(DefaultArticleCellController.self))
                }
            }
        }

        describe("Views") {
            exists(UnreadCounter.self)
            exists(TagPickerView.self)
        }

        describe("View Controllers") {
            describe("ArticleListController") {
                it("returns nil without an argument") {
                    expect(subject.resolve(ArticleListController.self)).to(beNil())
                }

                describe("if created with a feed") {
                    let feed: Feed = feedFactory()

                    it("exists") {
                        expect(subject.resolve(ArticleListController.self, argument: feed)).toNot(beNil())
                    }

                    it("sets the feed to the given feed") {
                        let controller = subject.resolve(ArticleListController.self, argument: feed)
                        expect(controller?.feed).to(equal(feed))
                    }
                }
            }
            exists(ArticleViewController.self)

            exists(DocumentationViewController.self)

            exists(FeedsListController.self)
            exists(FeedsTableViewController.self)
            exists(FeedViewController.self)
            exists(FindFeedViewController.self)

            exists(HTMLViewController.self)

            exists(MigrationViewController.self)


            exists(SettingsViewController.self)
            exists(SplitViewController.self)

            exists(TagEditorViewController.self)
        }

        func exists<T>(_ type: T.Type) {
            describe("\(type)") {
                it("exists") {
                    expect(subject.resolve(type)).toNot(beNil())
                }
            }
        }

        func singleton<T>(_ type: T.Type) {
            describe("\(type)") {
                it("exists") {
                    expect(subject.resolve(type)).toNot(beNil())
                }

                it("is a singleton") {
                    expect(subject.resolve(type)).to(beIdenticalTo(subject.resolve(type)))
                }
            }
        }

        func isA<T, U>(_ type: T.Type, kindOf otherType: U.Type) {
            describe("\(type)") {
                it("exists") {
                    expect(subject.resolve(type)).toNot(beNil())
                }

                it("is a \(otherType)") {
                    expect(subject.resolve(type)).to(beAKindOf(otherType))
                }
            }
        }

        func alwaysIs<T: Equatable>(_ type: T.Type, a obj: T) {
            describe("\(type)") {
                it("exists") {
                    expect(subject.resolve(type)).toNot(beNil())
                }

                it("is always \(obj)") {
                    expect(subject.resolve(type)).to(be(obj))
                }
            }
        }
    }
}
