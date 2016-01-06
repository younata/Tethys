import XCTest

class rNewsAcceptanceTests: XCTestCase {
        
    override func setUp() {
        super.setUp()

        continueAfterFailure = false
        XCUIApplication().launch()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func deleteEverything() {
        let app = XCUIApplication()
        let feedsNavigationBar = app.navigationBars["Feeds"]
        feedsNavigationBar.buttons["Edit"].tap()
        while app.cells.count > 0 {
            app.cells.buttons.elementBoundByIndex(0).tap()
            app.buttons["Delete"].tap()
        }
        feedsNavigationBar.buttons["Done"].tap()
    }
    
    func testLoadingWebFeed() {
        let app = XCUIApplication()

        deleteEverything()

        XCTAssertEqual(app.tables.cells.count, 0)

        app.navigationBars["Feeds"].buttons["Add"].tap()
        app.buttons["Add from Web"].tap()
        
        let enterUrlTextField = app.navigationBars["rNews.FindFeedView"].textFields["Enter URL"]
        enterUrlTextField.tap()
        enterUrlTextField.typeText("http://younata.github.io")
        app.typeText("\r")
        app.toolbars.buttons["Add Feed"].tap()

        let feedCell = app.cells.elementBoundByIndex(0)

        expectationForPredicate(NSPredicate(format: "exists == true"), evaluatedWithObject: feedCell, handler: nil)
        waitForExpectationsWithTimeout(10, handler: nil)

        deleteEverything()
    }
}
