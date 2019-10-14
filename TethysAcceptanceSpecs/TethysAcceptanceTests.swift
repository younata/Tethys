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
        self.waitForExpectations(timeout: 30, handler: nil)
    }

    func loadWebFeed() {
        let app = XCUIApplication()

        self.waitForThingToExist(app.navigationBars["Feeds"])
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))
        app.navigationBars["Feeds"].buttons["FeedList_OpenFindFeed"].tap()

        let enterUrlTextField = app.textFields["FindFeed_URLField"]
        self.waitForThingToExist(enterUrlTextField)
        expect(app.keyboards.element.exists).to(beTrue(), description: "Expected to show a keyboard")
        app.typeText("blog.rachelbrindle.com")
        app.typeText(XCUIKeyboardKey.return.rawValue)

        let addFeedButton = app.toolbars.buttons["FindFeed_SubscribeButton"]
        self.waitForThingToExist(addFeedButton)
        waitForPredicate(NSPredicate(format: "enabled == true"), object: addFeedButton)
        expect(addFeedButton.isHittable).to(beTrue())
        addFeedButton.tap()

        self.waitForThingToExist(app.cells["FeedList_Cell"])
    }

    func assertShareShows(shareButtonName: String, app: XCUIApplication) {
        app.buttons[shareButtonName].tap()

        let element: XCUIElement
        if app.sheets.buttons["Cancel"].exists {
            element = app.sheets.buttons["Cancel"]
        } else if app.otherElements["PopoverDismissRegion"].exists {
            element = app.otherElements["PopoverDismissRegion"]
        } else {
            return fail("No way to dismiss share sheet")
        }
        element.tap()
    }

    func testMakingScreenshots() {
        let app = XCUIApplication()

        self.waitForThingToExist(app.navigationBars["Feeds"])
        assertFirstLaunch(app: app)

        self.loadWebFeed()

        snapshot("01-feedsList", waitForLoadingIndicator: false)

        app.cells["FeedList_Cell"].tap()

        self.waitForThingToExist(app.navigationBars["Rachel Brindle"])

        snapshot("02-articlesList", waitForLoadingIndicator: false)

//        self.assertShareShows(shareButtonName: "ArticleListController_ShareFeed", app: app)

        app.staticTexts["Homemade thermostat for my apartment"].tap()

        self.waitForThingToExist(app.navigationBars["Homemade thermostat for my apartment"])

        snapshot("03-article", waitForLoadingIndicator: false)

//        self.assertShareShows(shareButtonName: "ArticleViewController_ShareArticle", app: app)
    }
}
