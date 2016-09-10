import XCTest

class rNewsAcceptanceTests: XCTestCase {
        
    override func setUp() {
        super.setUp()

        continueAfterFailure = false
        XCUIApplication().launch()

        setupSnapshot(XCUIApplication())
    }

    override func tearDown() {
        super.tearDown()
    }

    func waitForThingToExist(_ thing: AnyObject) {
        self.waitForPredicate(NSPredicate(format: "exists == true"), object: thing)
    }

    func waitForPredicate(_ predicate: NSPredicate, object: AnyObject) {
        expectation(for: predicate, evaluatedWith: object, handler: nil)
        waitForExpectations(timeout: 120, handler: nil)
    }

    func loadWebFeed() {
        let app = XCUIApplication()

        self.waitForThingToExist(app.navigationBars["Feeds"])
        app.navigationBars["Feeds"].buttons["Add"].tap()
        app.buttons["Add from Web"].tap()

        let enterUrlTextField = app.textFields["Enter URL"]
        enterUrlTextField.tap()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 10))
        app.typeText("http://younata.github.io")
        app.buttons["Return"].tap()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 10))

        let addFeedButton = app.toolbars.buttons["Add Feed"]

        self.waitForThingToExist(addFeedButton)

        addFeedButton.tap()

        let feedCell = app.cells.element(boundBy: 0)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 10))
        self.waitForThingToExist(feedCell)
    }

    func testMakingScreenshots() {
        let app = XCUIApplication()

        self.loadWebFeed()

        snapshot("01-feedsList", waitForLoadingIndicator: false)

        app.cells.element(boundBy: 0).tap()

        self.waitForThingToExist(app.navigationBars["Rachel Brindle"])

        snapshot("02-articlesList", waitForLoadingIndicator: false)

        app.staticTexts["Homemade thermostat for my apartment"].tap()

        self.waitForThingToExist(app.navigationBars["Homemade thermostat for my apartment"])

        snapshot("03-article", waitForLoadingIndicator: false)
    }
}
