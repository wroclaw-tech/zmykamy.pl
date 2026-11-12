import XCTest

/// Smoke tests for flows that work without a backend. Each test starts from a fresh install.
final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    override func setUp() async throws {
        app = XCUIApplication()
        app.launchArguments = ["-resetState"]
        app.launch()
    }

    @MainActor
    func testNewUserPicksAColorAndReachesSignUp() {
        button("Rozpocznij").tap()

        XCTAssertFalse(button("Wybierz opcję").isEnabled, "Can't continue before picking a color")
        app.buttons["Góry i jeziora, szlaki, schroniska, cisza"].tap()
        XCTAssertTrue(app.staticTexts["Twój kolor: las"].waitForExistence(timeout: 5))
        button("Dalej").tap()

        button("Gotowe").tap()

        XCTAssertTrue(app.textFields["Jak cię wołają?"].waitForExistence(timeout: 5))
        XCTAssertFalse(button("Utwórz konto").isEnabled)
    }

    @MainActor
    func testSignUpIsEnabledOnlyForValidDetails() {
        button("Rozpocznij").tap()
        button("Pomiń").tap()

        let submit = button("Utwórz konto")
        app.textFields["Jak cię wołają?"].tap()
        app.textFields["Jak cię wołają?"].typeText("Kuba")
        app.textFields["E-mail"].tap()
        app.textFields["E-mail"].typeText("kuba@zmykamy.pl")
        let password = app.secureTextFields["Hasło (min. 8 znaków)"]
        password.tap()
        if declineStrongPassword() { password.tap() }
        password.typeText("krotkie")
        XCTAssertEqual((password.value as? String)?.count, 7, "Password wasn't typed")
        XCTAssertFalse(submit.isEnabled, "Passwords shorter than 8 characters are rejected")

        password.typeText("1")
        XCTAssertTrue(submit.isEnabled)
    }

    @MainActor
    func testReturningUserGoesStraightToSignIn() {
        button("Mam już konto").tap()
        XCTAssertTrue(button("Zaloguj się").waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["Jak cię wołają?"].exists)

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(button("Zaloguj się").waitForExistence(timeout: 5), "Onboarding isn't shown again")
    }

    /// Some iOS versions offer a strong password when the sign-up password field gets focus. The sheet
    /// swallows typing, so close it. Returns whether it was shown.
    @MainActor
    private func declineStrongPassword() -> Bool {
        let fill = app.buttons["Fill Strong Password"]
        guard fill.waitForExistence(timeout: 3) else { return false }
        let close = app.buttons.matching(NSPredicate(format: "label IN %@ OR identifier IN %@", ["Close", "Zamknij"], ["Close", "close"])).firstMatch
        if close.exists { close.tap() } else { fill.swipeDown(velocity: .fast) }
        XCTAssertTrue(fill.waitForNonExistence(timeout: 5), "Strong password sheet didn't close")
        return true
    }

    /// Buttons whose label starts with `title`, since icons can add to the accessibility label.
    @MainActor
    private func button(_ title: String) -> XCUIElement {
        let element = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing button \(title)")
        return element
    }
}
