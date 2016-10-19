import Quick
import Nimble
import rNewsKit
import rNews
import Ra
import CBGPromise
import Result

class LoginViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: LoginViewController!
        var themeRepository: ThemeRepository!
        var navigationController: UINavigationController!
        var accountRepository: FakeAccountRepository!
        var rootViewController: UIViewController!
        var mainQueue: FakeOperationQueue!

        beforeEach {
            let injector = Injector()
            themeRepository = ThemeRepository(userDefaults: nil)
            injector.bind(kind: ThemeRepository.self, toInstance: themeRepository)

            accountRepository = FakeAccountRepository()
            injector.bind(kind: AccountRepository.self, toInstance: accountRepository)

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            injector.bind(string: kMainQueue, toInstance: mainQueue)

            subject = injector.create(kind: LoginViewController.self)!

            rootViewController = UIViewController()
            navigationController = UINavigationController(rootViewController: rootViewController)
            navigationController.pushViewController(subject, animated: false)
            expect(subject.view).toNot(beNil())
        }

        it("starts with the login button disabled") {
            expect(subject.loginButton.isEnabled) == false
        }

        it("starts with the register button disabled") {
            expect(subject.registerButton.isEnabled) == false
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("restyles the navigation bar") {
                expect(navigationController.navigationBar.barStyle) == themeRepository.barStyle
                expect(subject.navigationController?.navigationBar.titleTextAttributes as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
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

            it("changes the text color of the errorLabel") {
                expect(subject.errorLabel.textColor) == themeRepository.errorColor
            }

            it("changes the text color of the email field") {
                expect(subject.emailField.textColor) == themeRepository.textColor
            }

            it("changes the text color of the password field") {
                expect(subject.passwordField.textColor) == themeRepository.textColor
            }
        }

        describe("setting an accountType") {
            describe("to .Pasiphae") {
                beforeEach {
                    subject.accountType = .pasiphae
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
                _ = subject.emailField.delegate?.textField?(subject.emailField,
                                                        shouldChangeCharactersIn: NSRange(location: 0, length: 0),
                                                        replacementString: "")
            }

            let enterPassword = {
                subject.passwordField.text = "testere"
                _ = subject.passwordField.delegate?.textField?(subject.emailField,
                                                        shouldChangeCharactersIn: NSRange(location: 0, length: 0),
                                                        replacementString: "")
            }

            describe("entering email alone") {
                beforeEach {
                    enterEmail()
                }

                it("does not enable the login button") {
                    expect(subject.loginButton.isEnabled) == false
                }

                it("does not enable the register button") {
                    expect(subject.registerButton.isEnabled) == false
                }
            }

            describe("entering password alone") {
                beforeEach {
                    enterPassword()
                }

                it("does not enable the login button") {
                    expect(subject.loginButton.isEnabled) == false
                }

                it("does not enable the register button") {
                    expect(subject.registerButton.isEnabled) == false
                }
            }

            describe("entering both") {
                beforeEach {
                    enterEmail()
                    enterPassword()
                }

                it("enables the login button") {
                    expect(subject.loginButton.isEnabled) == true
                }

                it("enables the register button") {
                    expect(subject.registerButton.isEnabled) == true
                }

                describe("tapping the login button") {
                    var loginPromise: Promise<Result<Void, RNewsError>>!

                    beforeEach {
                        loginPromise = Promise<Result<Void, RNewsError>>()
                        accountRepository.loginReturns(loginPromise.future)

                        subject.loginButton.sendActions(for: .touchUpInside)
                    }

                    it("asks the account repository to log in") {
                        expect(accountRepository.loginCallCount) == 1
                        guard accountRepository.loginCallCount == 1 else { return }
                        let args = accountRepository.loginArgsForCall(0)
                        expect(args.0) == "foo@example.com"
                        expect(args.1) == "testere"
                    }

                    it("should present an activity indicator") {
                        var indicator : ActivityIndicator? = nil
                        for view in subject.view.subviews {
                            if view is ActivityIndicator {
                                indicator = view as? ActivityIndicator
                                break
                            }
                        }
                        expect(indicator).toNot(beNil())
                        if let activityIndicator = indicator {
                            expect(activityIndicator.message).to(equal("Logging In"))
                        }
                    }

                    describe("when the user successfully logs in") {
                        beforeEach {
                            loginPromise.resolve(.success())
                        }

                        it("dismisses the activity indicator") {
                            let subjectHasNoActivityIndicator = subject.view.subviews.filter { return $0.classForCoder == ActivityIndicator.classForCoder() }.count == 0
                            expect(subjectHasNoActivityIndicator).to(beTruthy())
                        }

                        it("dismisses the view controller") {
                            expect(navigationController.topViewController) == rootViewController
                        }
                    }

                    describe("when the user fails to log in") {
                        beforeEach {
                            loginPromise.resolve(.failure(.unknown))
                        }

                        it("dismisses the activity indicator") {
                            let subjectHasNoActivityIndicator = subject.view.subviews.filter { return $0.classForCoder == ActivityIndicator.classForCoder() }.count == 0
                            expect(subjectHasNoActivityIndicator).to(beTruthy())
                        }

                        it("shows an error indicating what went wrong") {
                            expect(subject.errorLabel.text) == "Unknown Error - please try again"
                        }
                    }
                }

                describe("tapping the register button") {
                    var registerPromise: Promise<Result<Void, RNewsError>>!

                    beforeEach {
                        registerPromise = Promise<Result<Void, RNewsError>>()
                        accountRepository.registerReturns(registerPromise.future)

                        subject.registerButton.sendActions(for: .touchUpInside)
                    }

                    it("asks the account repository to register") {
                        expect(accountRepository.registerCallCount) == 1
                        guard accountRepository.registerCallCount == 1 else { return }
                        let args = accountRepository.registerArgsForCall(0)
                        expect(args.0) == "foo@example.com"
                        expect(args.1) == "testere"
                    }

                    it("should present an activity indicator") {
                        var indicator : ActivityIndicator? = nil
                        for view in subject.view.subviews {
                            if view is ActivityIndicator {
                                indicator = view as? ActivityIndicator
                                break
                            }
                        }
                        expect(indicator).toNot(beNil())
                        if let activityIndicator = indicator {
                            expect(activityIndicator.message).to(equal("Registering"))
                        }
                    }

                    describe("when the user successfully registers") {
                        beforeEach {
                            registerPromise.resolve(.success())
                        }

                        it("dismisses the activity indicator") {
                            let subjectHasNoActivityIndicator = subject.view.subviews.filter { return $0.classForCoder == ActivityIndicator.classForCoder() }.count == 0
                            expect(subjectHasNoActivityIndicator).to(beTruthy())
                        }

                        it("dismisses the view controller") {
                            expect(navigationController.topViewController) == rootViewController
                        }
                    }

                    describe("when the user fails to register") {
                        beforeEach {
                            registerPromise.resolve(.failure(.unknown))
                        }

                        it("dismisses the activity indicator") {
                            let subjectHasNoActivityIndicator = subject.view.subviews.filter { return $0.classForCoder == ActivityIndicator.classForCoder() }.count == 0
                            expect(subjectHasNoActivityIndicator).to(beTruthy())
                        }

                        it("shows an error indicating what went wrong") {
                            expect(subject.errorLabel.text) == "Unknown Error - please try again"
                        }
                    }
                }
            }
        }
    }
}
