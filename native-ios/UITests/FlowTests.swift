import XCTest
final class FlowTests:XCTestCase {
    func capture(_ app:XCUIApplication,_ name:String) {
        let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    func launch()->XCUIApplication {
        let app=XCUIApplication();app.launchArguments=["-ui-testing"];app.launch();return app
    }
    func login(_ app:XCUIApplication) {
        let phone=app.textFields["phone"];XCTAssertTrue(phone.waitForExistence(timeout:10));phone.tap();phone.typeText("05321234567")
        let password=app.secureTextFields["password"];password.tap();password.typeText("test-password")
        app.buttons["login"].tap()
        XCTAssertTrue(app.buttons["learning"].waitForExistence(timeout:10))
        capture(app,"Home")
    }
    func testMotherLearningAndFAQNavigation() {
        let app=launch();login(app)
        app.buttons["learning"].tap();app.buttons["normalQuiz"].tap()
        XCTAssertTrue(app.buttons["Seçenekleri göster"].waitForExistence(timeout:5));app.buttons["Seçenekleri göster"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Cevap")).firstMatch.exists)
        capture(app,"Quiz")
    }
    func testLoginValidation() {
        let app=launch();XCTAssertTrue(app.buttons["login"].waitForExistence(timeout:10));XCTAssertFalse(app.buttons["login"].isEnabled)
        capture(app,"Login")
    }
    func testElderRoleAndAdminPanel() {
        let app=launch()
        XCTAssertTrue(app.segmentedControls["rolePicker"].waitForExistence(timeout:10))
        app.segmentedControls["rolePicker"].buttons["Üst Kuşak"].tap()
        login(app)
        XCTAssertTrue(app.staticTexts["Üst Kuşak"].exists)
        app.terminate();app.launch()
        app.segmentedControls["rolePicker"].buttons["Admin"].tap()
        let phone=app.textFields["phone"];phone.tap();phone.typeText("05321234567")
        let password=app.secureTextFields["password"];password.tap();password.typeText("test-password")
        app.buttons["login"].tap()
        XCTAssertTrue(app.tabBars.buttons["Üyeler"].waitForExistence(timeout:10))
        app.tabBars.buttons["SSS"].tap()
        XCTAssertTrue(app.staticTexts["Destek nasıl alınır?"].waitForExistence(timeout:5))
        capture(app,"AdminFAQ")
    }
}
