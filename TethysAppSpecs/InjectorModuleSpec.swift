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
            alwaysIs(Bundle.self, a: Bundle.main)
            alwaysIs(FileManager.self, a: FileManager.default)
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

            exists(FeedsDeleSource.self)

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
            exists(SplitViewController.self)
            exists(MigrationViewController.self)
            exists(TagEditorViewController.self)

            exists(FeedViewController.self)
            exists(FeedsTableViewController.self)
            exists(FindFeedViewController.self)
            exists(FeedsListController.self)

            exists(SettingsViewController.self)

            exists(ArticleViewController.self)
            exists(ArticleListController.self)

            exists(ChapterOrganizerController.self)
            exists(GenerateBookViewController.self)

            exists(DocumentationViewController.self)

            exists(HTMLViewController.self)
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

        func isA<T, U>(_ type: T.Type, kindOf otherType: U.Type) {
            describe(Mirror(reflecting: type).description) {
                it("exists") {
                    expect(subject.resolve(type)).toNot(beNil())
                }

                it("is a \(Mirror(reflecting: otherType).description)") {
                    expect(subject.resolve(type)).to(beAKindOf(otherType))
                }
            }
        }

        func alwaysIs<T: Equatable>(_ type: T.Type, a obj: T) {
            describe(Mirror(reflecting: type).description) {
                it("exists") {
                    expect(subject.resolve(type)).toNot(beNil())
                }

                it("is always \(Mirror(reflecting: obj).description)") {
                    expect(subject.resolve(type)).to(be(obj))
                }
            }
        }
    }
}
