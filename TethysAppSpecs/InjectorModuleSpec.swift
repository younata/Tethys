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
            singleton(LocalNotificationSource.self)
        }

        describe("Use Cases and Handlers") {
            isA(BackgroundFetchHandler.self, kindOf: DefaultBackgroundFetchHandler.self)
            isA(NotificationHandler.self, kindOf: LocalNotificationHandler.self)

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
        }

        describe("Views") {
            exists(UnreadCounter.self)
            exists(TagPickerView.self)
        }

        describe("View Controllers") {
            exists(ArticleListController.self)
            exists(ArticleViewController.self)

            exists(ChapterOrganizerController.self)

            exists(DocumentationViewController.self)

            exists(FeedsListController.self)
            exists(FeedsTableViewController.self)
            exists(FeedViewController.self)
            exists(FindFeedViewController.self)

            exists(GenerateBookViewController.self)

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
