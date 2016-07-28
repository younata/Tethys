import Quick
import Nimble
import rNewsKit
import rNews
import Ra

class LoginViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: LoginViewController!
        var themeRepository: ThemeRepository!
        var navigationController: UINavigationController!

        beforeEach {
            let injector = Injector()
            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, toInstance: themeRepository)

            subject = injector.create(LoginViewController)!

            navigationController = UINavigationController(rootViewController: subject)
            expect(subject.view).toNot(beNil())
        }

        it("starts with the login button disabled") {
            expect(subject.loginButton.enabled) == false
        }

        it("starts with the register button disabled") {
            expect(subject.registerButton.enabled) == false
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("restyles the navigation bar") {
                expect(navigationController.navigationBar.barStyle) == themeRepository.barStyle
            }

            it("changes the background color of the view") {
                expect(subject.view.backgroundColor) == themeRepository.backgroundColor
            }

            it("changes the text color of the titleLabel") {
                expect(subject.titleLabel.textColor) == themeRepository.textColor
            }

            it("changes the text color of the detailLabel") {
                expect(subject.detailLabel.textColor) == themeRepository.textColor
            }
        }

        describe("setting an accountType") {
            describe("to .Pasiphae") {
                beforeEach {
                    subject.accountType = .Pasiphae
                }

                it("sets the view title to 'rNews Backend'") {
                    expect(subject.title) == "rNews Backend"
                }

                it("sets the title label to 'Log in to rNews'") {
                    expect(subject.titleLabel.text) == "Log in to rNews"
                }

                it("offers a nice explanation for why you'd want to do this") {
                    expect(subject.detailLabel.text) == ""
                }
            }
        }

        describe("logging in") {
            let enterEmail = {
                subject.emailField.text = "foo@example.com"
                subject.emailField.delegate?.textField?(subject.emailField,
                                                        shouldChangeCharactersInRange: NSRange(location: 0, length: 0),
                                                        replacementString: "")
            }

            let enterPassword = {
                subject.passwordField.text = "foo@example.com"
                subject.passwordField.delegate?.textField?(subject.emailField,
                                                        shouldChangeCharactersInRange: NSRange(location: 0, length: 0),
                                                        replacementString: "")
            }

            describe("entering email alone") {
                beforeEach {
                    enterEmail()
                }

                it("does not enable the login button") {
                    expect(subject.loginButton.enabled) == false
                }

                it("does not enable the register button") {
                    expect(subject.registerButton.enabled) == false
                }
            }

            describe("entering password alone") {
                beforeEach {
                    enterPassword()
                }

                it("does not enable the login button") {
                    expect(subject.loginButton.enabled) == false
                }

                it("does not enable the register button") {
                    expect(subject.registerButton.enabled) == false
                }
            }

            describe("entering both") {
                beforeEach {
                    enterEmail()
                    enterPassword()
                }

                it("enables the login button") {
                    expect(subject.loginButton.enabled) == true
                }

                it("enables the register button") {
                    expect(subject.registerButton.enabled) == true
                }

                describe("tapping the login button") {
                    beforeEach {
                        subject.loginButton.tap()
                    }
                }

                describe("tapping the register button") {
                    beforeEach {
                        subject.registerButton.tap()
                    }
                }
            }
        }
    }
}
