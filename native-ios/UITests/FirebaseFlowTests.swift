import XCTest

final class FirebaseFlowTests:XCTestCase {
    func authenticate(_ app:XCUIApplication,phone:String,role:String) {
        XCTAssertTrue(app.segmentedControls["rolePicker"].waitForExistence(timeout:20))
        app.segmentedControls["rolePicker"].buttons[role].tap()
        let field=app.textFields["phone"];field.tap();field.typeText(phone)
        let password=app.secureTextFields["password"];password.tap();password.typeText("test-password")
        app.buttons["login"].tap()
    }
    func testRealFirebaseLoginQuizAndExpertConversation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_FIREBASE_UI_TESTS"]=="1","Requires local demo Firebase emulators.")
        let app=XCUIApplication();app.launchArguments=["-emulator-testing"];app.launch()
        authenticate(app,phone:"05321234567",role:"Anne")
        XCTAssertTrue(app.buttons["learning"].waitForExistence(timeout:60))
        app.buttons["learning"].tap();app.buttons["normalQuiz"].tap()
        let question=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Örnek soru ")).firstMatch
        XCTAssertTrue(question.waitForExistence(timeout:10))
        let number=question.label.split(separator:" ").last.map(String.init) ?? ""
        app.buttons["Seçenekleri göster"].tap()
        app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Cevap \(number)")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Doğru cevap!"].waitForExistence(timeout:30))
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.buttons["Danış"].tap()
        let draft=app.textFields["chatDraft"];XCTAssertTrue(draft.waitForExistence(timeout:10));draft.tap();draft.typeText("Uzman desteği istiyorum")
        app.buttons["chatSend"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Sorunuzu uzman desteğine yönlendirdim")).firstMatch.waitForExistence(timeout:60))
        app.terminate();app.launch()
        authenticate(app,phone:"05321234569",role:"Admin")
        XCTAssertTrue(app.buttons["user-mother"].waitForExistence(timeout:60));app.buttons["user-mother"].tap()
        app.buttons["userChat"].tap()
        XCTAssertTrue(app.buttons["Bu soruyu yanıtla"].firstMatch.waitForExistence(timeout:20));app.buttons["Bu soruyu yanıtla"].firstMatch.tap()
        let expertDraft=app.textFields["chatDraft"];expertDraft.tap();expertDraft.typeText("Uzman test yanıtı")
        app.buttons["chatSend"].tap()
        XCTAssertTrue(app.staticTexts["Uzman yanıtladı"].firstMatch.waitForExistence(timeout:30))
        app.terminate();app.launch()
        authenticate(app,phone:"05321234567",role:"Anne")
        XCTAssertTrue(app.buttons["Danış"].waitForExistence(timeout:60));app.buttons["Danış"].tap()
        XCTAssertTrue(app.staticTexts["Uzman test yanıtı"].waitForExistence(timeout:20))
        let screenshot=XCTAttachment(screenshot:app.screenshot());screenshot.name="Firebase-expert-conversation";screenshot.lifetime = .keepAlways;add(screenshot)
    }
}
