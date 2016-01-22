import XCTest

class rNewsAcceptanceTests: XCTestCase {
        
    override func setUp() {
        super.setUp()

        continueAfterFailure = false
        XCUIApplication().launch()

        setupSnapshot(XCUIApplication())

        deleteEverything()
    }

    override func tearDown() {
        super.tearDown()
    }

    func deleteEverything() {
        let app = XCUIApplication()
        let feedsNavigationBar = app.navigationBars["Feeds"]
        feedsNavigationBar.buttons["Edit"].tap()
        self.waitForThingToExist(feedsNavigationBar.buttons["Done"])
        var count = Int(app.tables.cells.count)
        while app.cells.count > 0 {
            app.cells.buttons.elementBoundByIndex(0).tap()

            let deleteButton = app.buttons["Delete"]
            self.waitForThingToExist(deleteButton)

            deleteButton.tap()

            count -= 1
            self.waitForPredicate(NSPredicate(format: "count == \(count)"), object: app.tables.cells)
        }
        feedsNavigationBar.buttons["Done"].tap()
        XCTAssertEqual(app.tables.cells.count, 0)
    }

    func waitForThingToExist(thing: AnyObject) {
        self.waitForPredicate(NSPredicate(format: "exists == true"), object: thing)
    }

    func waitForPredicate(predicate: NSPredicate, object: AnyObject) {
        expectationForPredicate(predicate, evaluatedWithObject: object, handler: nil)
        waitForExpectationsWithTimeout(60, handler: nil)
    }

    func testLoadingWebFeed() {
        let app = XCUIApplication()

        app.navigationBars["Feeds"].buttons["Add"].tap()
        app.buttons["Add from Web"].tap()
        
        let enterUrlTextField = app.navigationBars["rNews.FindFeedView"].textFields["Enter URL"]
        enterUrlTextField.tap()
        enterUrlTextField.typeText("http://younata.github.io\r")

        let addFeedButton = app.toolbars.buttons["Add Feed"]

        self.waitForThingToExist(addFeedButton)

        addFeedButton.tap()

        let feedCell = app.cells.elementBoundByIndex(0)

        self.waitForThingToExist(feedCell)
    }

    func testMakingScreenshots() {
        let app = XCUIApplication()

        self.testLoadingWebFeed()

        snapshot("01-feedsList")

        app.cells.elementBoundByIndex(0).tap()

        self.waitForThingToExist(app.navigationBars["Rachel Brindle"])

        snapshot("02-articlesList")

        app.staticTexts["Homemade thermostat for my apartment"].tap()

        self.waitForThingToExist(app.navigationBars["Homemade thermostat for my apartment"])

        snapshot("03-article")
    }
}
