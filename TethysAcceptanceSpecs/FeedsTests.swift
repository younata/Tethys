import XCTest

func assertFirstLaunch(app: XCUIApplication) {
    assertFeedsList(app: app)

    XCTAssertEqual(
        app.cells.count, 0,
        "feeds list has no feeds loaded"
    )

    // Doesn't show the 'loading feeds' dialog.
    XCTAssertFalse(
        app.staticTexts["loading feeds"].exists,
        "feeds list is not showing the 'loading feeds' dialog'"
    )
    XCTAssertEqual(
        app.activityIndicators.count, 0,
        "feeds list is not showing the activity indicator"
    )
}

func assertSecondLaunch(app: XCUIApplication) {
    assertFeedsList(app: app)

    XCTAssertGreaterThan(
        app.cells.count, 0,
        "feeds list has at least 1 feed loaded"
    )

    XCTAssertTrue(
        app.staticTexts["loading feeds"].exists,
        "feeds list is showing the 'loading feeds' dialog'"
    )
    XCTAssertGreaterThan(
        app.activityIndicators.count, 1,
        "feeds list is showing the activity indicator"
    )
}

private func assertFeedsList(app: XCUIApplication) {
    XCTAssertTrue(
        app.navigationBars["Feeds"].buttons["Settings"].exists,
        "feeds list has a button to enter settings"
    )
    XCTAssertTrue(
        app.navigationBars["Feeds"].buttons["Add"].exists,
        "feeds list has a button to add more feeds"
    )
}
