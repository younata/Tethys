import XCTest
import Nimble

class TethysAcceptanceTests: XCTestCase {
        
    override func setUp() {
        super.setUp()

        self.continueAfterFailure = false
        setupSnapshot(XCUIApplication())

        XCUIApplication().launch()
    }

    override func tearDown() {
        super.tearDown()
    }

    func waitForThingToExist(_ thing: AnyObject) {
        self.waitForPredicate(NSPredicate(format: "exists == true"), object: thing)
    }

    func waitForPredicate(_ predicate: NSPredicate, object: AnyObject) {
        self.expectation(for: predicate, evaluatedWith: object, handler: nil)
        self.waitForExpectations(timeout: 10, handler: nil)
    }

    func loadWebFeed() {
        let app = XCUIApplication()

        self.waitForThingToExist(app.navigationBars["Feeds"])
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))
        app.navigationBars["Feeds"].buttons["Add"].tap()

        let enterUrlTextField = app.textFields["Enter URL"]
        self.waitForThingToExist(enterUrlTextField)
        expect(app.keyboards.element.exists).to(beTrue(), description: "Expected to show a keyboard")
        app.typeText("blog.rachelbrindle.com")
        app.buttons["Return"].tap()

        let addFeedButton = app.toolbars.buttons["Add Feed"]
        self.waitForThingToExist(addFeedButton)
        addFeedButton.tap()

        self.waitForThingToExist(app.cells["Rachel Brindle"])
    }

    func testMakingScreenshots() {
        let app = XCUIApplication()

        self.waitForThingToExist(app.navigationBars["Feeds"])
        assertFirstLaunch(app: app)

        self.loadWebFeed()

        snapshot("01-feedsList", waitForLoadingIndicator: false)

        app.cells["Rachel Brindle"].tap()

        self.waitForThingToExist(app.navigationBars["Rachel Brindle"])

        snapshot("02-articlesList", waitForLoadingIndicator: false)

        app.staticTexts["Homemade thermostat for my apartment"].tap()

        self.waitForThingToExist(app.navigationBars["Homemade thermostat for my apartment"])

        snapshot("03-article", waitForLoadingIndicator: false)
    }
}
