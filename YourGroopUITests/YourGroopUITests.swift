import XCTest

final class YourGroopUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testNavigateFromMyGroopsToDetail() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_AUTOSIGNIN")
        app.launch()

        let myGroopsTab = app.tabBars.buttons["My Groops"]
        XCTAssertTrue(myGroopsTab.waitForExistence(timeout: 5))
        myGroopsTab.tap()

        let groopRow = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'myGroopRow_'")).firstMatch
        XCTAssertTrue(groopRow.waitForExistence(timeout: 5))
        groopRow.tap()

        XCTAssertTrue(app.navigationBars["Groop Detail"].waitForExistence(timeout: 5))
    }
}
