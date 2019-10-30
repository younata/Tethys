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

            exists(Messenger.self)

            exists(AppIconChanger.self)
        }

        describe("Repositories") {
            singleton(SettingsRepository.self)
        }

        describe("Controllers") {
            isA(ArticleUseCase.self, kindOf: DefaultArticleUseCase.self)

            describe("ArticleCellController") {
                it("requires a bool argument") {
                    expect(subject.resolve(ArticleCellController.self)).to(beNil())
                    expect(subject.resolve(ArticleCellController.self, argument: false)).to(beAKindOf(DefaultArticleCellController.self))
                    expect(subject.resolve(ArticleCellController.self, argument: true)).to(beAKindOf(DefaultArticleCellController.self))
                }
            }

            isA(LoginController.self, kindOf: OAuthLoginController.self)
        }

        describe("Views") {
            exists(TagPickerView.self)
        }

        describe("Easter Eggs") {
            exists(AugmentedRealityEasterEggViewController.self)
            exists(Breakout3DEasterEggViewController.self)
            exists(RogueLikeViewController.self)

            describe("EasterEggGalleryViewController") {
                it("configures the returned view controller with the current list of easter eggs") {
                    let vc = subject.resolve(EasterEggGalleryViewController.self)
                    expect(vc).toNot(beNil())
                    expect(vc?.easterEggs).to(equal([
                        EasterEgg(name: "3D Breakout", image: UIImage(named: "Breakout3DIcon")!, viewController: { breakout3DEasterEggViewControllerFactory() }),
                        EasterEgg(name: "Roguelike Game", image: UIImage(named: "EasterEggUnknown")!, viewController: { RogueLikeViewController() })
                    ]))
                }
            }
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
            describe("ArticleViewController") {
                it("returns nil without an argument") {
                    expect(subject.resolve(ArticleViewController.self)).to(beNil())
                }

                describe("if created with an article") {
                    let article: Article = articleFactory()

                    it("exists") {
                        expect(subject.resolve(ArticleViewController.self, argument: article)).toNot(beNil())
                    }

                    it("sets the feed to the given article") {
                        let controller = subject.resolve(ArticleViewController.self, argument: article)
                        expect(controller?.article).to(equal(article))
                    }
                }
            }

            describe("DocumentationViewController") {
                it("returns nil without an argument") {
                    expect(subject.resolve(DocumentationViewController.self)).to(beNil())
                }

                describe("if created with an article") {
                    let documentation = Documentation.icons

                    it("exists") {
                        expect(subject.resolve(DocumentationViewController.self, argument: documentation)).toNot(beNil())
                    }
                }
            }

            exists(FeedListController.self)
            describe("FeedViewController") {
                it("returns nil without an argument") {
                    expect(subject.resolve(FeedViewController.self)).to(beNil())
                }

                describe("if created with a feed") {
                    let feed: Feed = feedFactory()

                    it("exists") {
                        expect(subject.resolve(FeedViewController.self, argument: feed)).toNot(beNil())
                    }

                    it("sets the feed to the given feed") {
                        let controller = subject.resolve(FeedViewController.self, argument: feed)
                        expect(controller?.feed).to(equal(feed))
                    }
                }
            }
            exists(FindFeedViewController.self)

            exists(HTMLViewController.self)

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
