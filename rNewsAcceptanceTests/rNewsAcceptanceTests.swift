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

    func waitForThingToExist(thing: AnyObject) {
        self.waitForPredicate(NSPredicate(format: "exists == true"), object: thing)
    }

    func waitForPredicate(predicate: NSPredicate, object: AnyObject) {
        expectationForPredicate(predicate, evaluatedWithObject: object, handler: nil)
        waitForExpectationsWithTimeout(120, handler: nil)
    }

    func loadWebFeed() {
        let app = XCUIApplication()

        self.waitForThingToExist(app.navigationBars["Feeds"])
        app.navigationBars["Feeds"].buttons["Add"].tap()
        app.buttons["Add from Web"].tap()

        let enterUrlTextField = app.textFields["Enter URL"]
        enterUrlTextField.tap()
        NSRunLoop.mainRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 10))
        app.typeText("http://younata.github.io")
        app.buttons["Return"].tap()
        NSRunLoop.mainRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 10))

        let addFeedButton = app.toolbars.buttons["Add Feed"]

        self.waitForThingToExist(addFeedButton)

        addFeedButton.tap()

        let feedCell = app.cells.elementBoundByIndex(0)

        NSRunLoop.mainRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 10))
        self.waitForThingToExist(feedCell)
    }

    func testMakingScreenshots() {
        let app = XCUIApplication()

        self.loadWebFeed()

        snapshot("01-feedsList", waitForLoadingIndicator: false)

        app.cells.elementBoundByIndex(0).tap()

        self.waitForThingToExist(app.navigationBars["Rachel Brindle"])

        snapshot("02-articlesList", waitForLoadingIndicator: false)

        app.staticTexts["Homemade thermostat for my apartment"].tap()

        self.waitForThingToExist(app.navigationBars["Homemade thermostat for my apartment"])

        snapshot("03-article", waitForLoadingIndicator: false)
    }
}
