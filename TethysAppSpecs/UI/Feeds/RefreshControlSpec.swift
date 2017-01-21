import Quick
import Nimble
import Tethys

class FakeRefresher: Refresher {
    var refreshCallCount: Int = 0
    func refresh() {
        refreshCallCount += 1
    }
}

class FakeLowPowerDiviner: LowPowerDiviner {
    var isLowPowerModeEnabled: Bool = false
}

class RefreshControlSpec: QuickSpec {
    override func spec() {
        var subject: RefreshControl!

        var notificationCenter: NotificationCenter!
        var scrollView: UIScrollView!
        var mainQueue: FakeOperationQueue!
        var themeRepository: ThemeRepository!
        var settingsRepository: SettingsRepository!
        var refresher: FakeRefresher!
        var lowPowerDiviner: FakeLowPowerDiviner!

        beforeEach {
            notificationCenter = NotificationCenter()
            scrollView = UIScrollView()
            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            themeRepository = ThemeRepository(userDefaults: nil)
            settingsRepository = SettingsRepository(userDefaults: nil)
            refresher = FakeRefresher()
            lowPowerDiviner = FakeLowPowerDiviner()

            subject = RefreshControl(
                notificationCenter: notificationCenter,
                scrollView: scrollView,
                mainQueue: mainQueue,
                themeRepository: themeRepository,
                settingsRepository: settingsRepository,
                refresher: refresher,
                lowPowerDiviner: lowPowerDiviner
            )
        }

        describe("when the theme changes") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("updates the breakoutView's colors") {
                expect(subject.breakoutView.scenebackgroundColor) == themeRepository.backgroundColor
                expect(subject.breakoutView.textColor) == themeRepository.textColor
            }

            it("updates the spinner's colors") {
                expect(subject.spinner.tintColor) == themeRepository.textColor
            }
        }

        describe("when the user changes refresh styles") {
            beforeEach {
                settingsRepository.refreshControl = .spinner
            }

            it("switches to that refresh style") {
                expect(scrollView.refreshControl) == subject.spinner
                expect(subject.breakoutView.superview).to(beNil())
            }
        }

        describe("when in low power mode") {
            beforeEach {
                lowPowerDiviner.isLowPowerModeEnabled = true

                subject = RefreshControl(
                    notificationCenter: notificationCenter,
                    scrollView: scrollView,
                    mainQueue: mainQueue,
                    themeRepository: themeRepository,
                    settingsRepository: settingsRepository,
                    refresher: refresher,
                    lowPowerDiviner: lowPowerDiviner
                )
            }

            it("sets the scrollview's refreshControl") {
                expect(scrollView.refreshControl) == subject.spinner
            }

            it("does not install the breakout view") {
                expect(subject.breakoutView.superview).to(beNil())
            }

            describe("when switching out of low power mode") {
                beforeEach {
                    lowPowerDiviner.isLowPowerModeEnabled = false
                }

                context("and the user had preferred breakout") {
                    beforeEach {
                        notificationCenter.post(name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                                                object: nil,
                                                userInfo: nil)
                    }

                    it("unsets the scrollview's refreshControl") {
                        expect(scrollView.refreshControl).to(beNil())
                    }

                    it("installs the breakout view") {
                        expect(subject.breakoutView.superview) == scrollView
                    }
                }
            }
        }

        describe("when not in low power mode") {
            it("does not set the scrollview's refreshControl") {
                expect(scrollView.refreshControl).to(beNil())
            }

            it("installs the breakout view") {
                expect(subject.breakoutView.superview) == scrollView
            }

            describe("when switching into low power mode") {
                beforeEach {
                    lowPowerDiviner.isLowPowerModeEnabled = true
                    notificationCenter.post(name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                                            object: nil,
                                            userInfo: nil)
                }

                it("sets the scrollview's refreshControl") {
                    expect(scrollView.refreshControl) == subject.spinner
                }

                it("uninstalls the breakout view") {
                    expect(subject.breakoutView.superview).to(beNil())
                }
            }
        }

        it("triggers a refresh when the spinner activates") {
            subject.spinner.sendActions(for: .valueChanged)

            expect(refresher.refreshCallCount) == 1
        }

        it("triggers a refresh when the breakout view activates") {
            subject.refreshViewDidRefresh(subject.breakoutView)

            expect(refresher.refreshCallCount) == 1
        }
    }
}
