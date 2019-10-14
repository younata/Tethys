import XCTest
import Nimble

func assertFirstLaunch(app: XCUIApplication, file: FileString = #file, line: UInt = #line) {
    assertFeedsList(app: app, file: file, line: line)

    expect(app.cells.count, file: file, line: line).to(equal(0), description: "feeds list should have feeds loaded")

    // Doesn't show the 'loading feeds' dialog.
    expect(app.staticTexts["loading feeds"].exists, file: file, line: line).to(beFalse(), description: "feeds list should not show the 'loading feeds' dialog'")
    expect(app.activityIndicators.count, file: file, line: line).to(equal(0), description: "feeds list should not show any activity indicators")
}

func assertSecondLaunch(app: XCUIApplication, file: FileString = #file, line: UInt = #line) {
    assertFeedsList(app: app, file: file, line: line)

    expect(app.cells.count, file: file, line: line).to(beGreaterThan(0), description: "Expected feeds list to have at least 1 feed loaded")
    expect(app.staticTexts["loading feeds"].exists, file: file, line: line).to(beTrue(), description: "Expected to show the 'loading feeds' dialog")
    expect(app.activityIndicators.count, file: file, line: line).to(beGreaterThan(1), description: "feeds list is showing the activity indicator")
}

private func assertFeedsList(app: XCUIApplication, file: FileString, line: UInt) {
    expect(app.navigationBars["Feeds"].buttons["Settings"].exists, file: file, line: line).to(beTrue(), description: "Expected to show the settings button on the feeds list")
    expect(app.navigationBars["Feeds"].buttons["FeedList_OpenFindFeed"].exists, file: file, line: line).to(beTrue(), description: "Expected to show button to add more feeds")
}
