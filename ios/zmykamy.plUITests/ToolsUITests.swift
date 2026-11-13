import XCTest

final class ToolsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetState", "-toolsPreview"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Narzędzia"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testCalculatorPrefillsForeignExpense() {
        let app = launch()
        capture(app, "tools-hub")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Kalkulator walut")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["106,75 PLN"].waitForExistence(timeout: 10))
        capture(app, "currency-calculator")
        app.buttons["Dodaj jako wydatek"].tap()
        let amount = app.textFields["Kwota"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.value as? String, "25")
        XCTAssertTrue(app.buttons["Waluta wydatku: EUR"].exists)
        XCTAssertFalse(app.buttons["Dodaj wydatek"].isEnabled)
        capture(app, "foreign-expense")
    }

    @MainActor func testTappingTheNbpRateLetsYouEnterYourOwn() {
        let app = launch()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Kalkulator walut")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Dodaj jako wydatek"].waitForExistence(timeout: 10))
        app.buttons["Dodaj jako wydatek"].tap()
        let nbpRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Kurs średni NBP")).firstMatch
        XCTAssertTrue(nbpRow.waitForExistence(timeout: 10))

        nbpRow.tap()
        let rate = app.textFields["Kurs za 1 EUR"]
        XCTAssertTrue(rate.waitForExistence(timeout: 5))
        app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "4")

        XCTAssertEqual(rate.value as? String, "4")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "≈ 100")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Wróć do kursu NBP"].exists)
        capture(app, "foreign-expense-custom-rate")
    }

    @MainActor func testUnitConverterChangesCategoryAndSwapsDirection() {
        let app = launch()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Jednostki")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["3,11"].waitForExistence(timeout: 5))
        capture(app, "unit-converter")
        app.buttons["Zamień kierunek przeliczania"].tap()
        XCTAssertEqual(app.textFields["Wartość do przeliczenia"].value as? String, "3,106856")
        app.buttons["Temp."].tap()
        XCTAssertTrue(app.staticTexts["75,2"].waitForExistence(timeout: 5))
        app.buttons["Waga"].tap()
        XCTAssertTrue(app.staticTexts["11,02"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bagaż podręczny")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["22,05"].waitForExistence(timeout: 5))
    }
}
