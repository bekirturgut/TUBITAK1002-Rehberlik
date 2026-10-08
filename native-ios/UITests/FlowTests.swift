import XCTest
final class FlowTests:XCTestCase {
    func launch()->XCUIApplication {
        let app=XCUIApplication();app.launchArguments=["-ui-testing"];app.launch();return app
    }
    func login(_ app:XCUIApplication) {
        let phone=app.textFields["phone"];XCTAssertTrue(phone.waitForExistence(timeout:10));phone.tap();phone.typeText("05321234567")
        let password=app.secureTextFields["password"];password.tap();password.typeText("test-password")
        app.buttons["login"].tap()
        XCTAssertTrue(app.buttons["learning"].waitForExistence(timeout:10))
    }
    func testMotherLearningAndFAQNavigation() {
        let app=launch();login(app)
        app.buttons["learning"].tap();app.buttons["normalQuiz"].tap()
        XCTAssertTrue(app.buttons["Seçenekleri göster"].waitForExistence(timeout:5));app.buttons["Seçenekleri göster"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Cevap")).firstMatch.exists)
    }
    func testLoginValidation() {
        let app=launch();XCTAssertTrue(app.buttons["login"].waitForExistence(timeout:10));XCTAssertFalse(app.buttons["login"].isEnabled)
    }
}
