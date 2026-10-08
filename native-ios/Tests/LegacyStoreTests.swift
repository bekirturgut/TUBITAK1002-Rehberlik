import XCTest
import FirebaseCore
import FirebaseFirestore
import RehberlikCore
@testable import Rehberlik

final class LegacyStoreTests:XCTestCase {
    func testRealLegacyLoginEditingQuizAndDeletion() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_FIREBASE_UI_TESTS"]=="1","Requires isolated demo Firestore.")
        let done=expectation(description:"Legacy Firestore operations")
        Task { @MainActor in
            do {try await exerciseLegacyStore()} catch {XCTFail("Legacy Firestore operation failed: \(error)")}
            done.fulfill()
        }
        wait(for:[done],timeout:90)
    }
    @MainActor
    private func exerciseLegacyStore() async throws {
        print("LegacyStore: configuring isolated Firestore")
        let options=FirebaseOptions(googleAppID:"1:123:ios:abc123",gcmSenderID:"123")
        options.projectID="demo-rehberlik";options.apiKey="fake-api-key"
        if FirebaseApp.app(name:"LegacyStoreTests")==nil {FirebaseApp.configure(name:"LegacyStoreTests",options:options)}
        let db=Firestore.firestore(app:FirebaseApp.app(name:"LegacyStoreTests")!)
        let settings=db.settings;settings.host="127.0.0.1:8080";settings.isSSLEnabled=false;db.settings=settings
        let store=AppStore(database:db),uid="legacy-store-"+UUID().uuidString
        let ref=db.collection("users").document(uid)
        print("LegacyStore: creating test profile")
        try await store.saveUser(id:nil,creationID:uid,data:["name":"Test","surname":"Legacy","phone":"+905320000001","role":"Anne","password":"1234"])
        print("LegacyStore: reading test profile")
        let value1=try await ref.getDocument().data()?["password"] as? String;XCTAssertEqual(value1,"1234")
        try await store.saveUser(id:uid,creationID:uid,data:["name":"Updated","surname":"Legacy","phone":"+905320000001","role":"Anne"])
        let value2=try await ref.getDocument().data()?["password"] as? String;XCTAssertEqual(value2,"1234")
        do {try await store.login(phone:"05320000001",password:"wrong",role:.mother,remember:false);XCTFail("Wrong password accepted")}catch{}
        do {try await store.login(phone:"05320000001",password:"1234",role:.admin,remember:false);XCTFail("Wrong role accepted")}catch{}
        print("LegacyStore: checking login")
        try await store.login(phone:"05320000001",password:" 1234 ",role:.mother,remember:false)
        for _ in 0..<100 {if store.profile?.id==uid && store.eligibleCards.count==4{break};try await Task.sleep(nanoseconds:50_000_000)}
        XCTAssertEqual(store.profile?.id,uid);XCTAssertEqual(store.eligibleCards.count,4)
        let value3=try await ref.collection("loginHistory").getDocuments().count;XCTAssertEqual(value3,1)
        var random=SystemRandomNumberGenerator()
        let question=try LearningPolicy.questions(store.eligibleCards,using:&random)[0]
        let progressID="MotherLearnCard_"+question.id
        print("LegacyStore: writing quiz results")
        let wrong=try await store.recordAnswer(question,option:"wrong option");XCTAssertFalse(wrong)
        let value4=try await ref.collection("wrongCards").document(progressID).getDocument().exists;XCTAssertTrue(value4)
        let right=try await store.recordAnswer(question,option:question.card.answer);XCTAssertTrue(right)
        let value5=try await ref.collection("wrongCards").document(progressID).getDocument().exists;XCTAssertFalse(value5)
        let value6=try await ref.collection("correctCards").document(progressID).getDocument().data()?["answer"] as? String;XCTAssertEqual(value6,question.card.answer)
        let stats=try await ref.getDocument().data()?["quizStats"] as? [String:Any]
        XCTAssertEqual(stats?["percent"] as? Int,25);XCTAssertEqual(stats?["earnedBadges"] as? [Int],[25])
        let value7=try await db.collection("_credentials").document(uid).getDocument().exists;XCTAssertFalse(value7)
        XCTAssertFalse(UserDefaults.standard.bool(forKey:"native.remember"))
        await store.logout();XCTAssertNil(store.profile)
        try await ref.collection("scheduledNotifs").document("test").setData(["templateId":"test"])
        try await ref.collection("notifications").document("test").setData(["title":"test"])
        print("LegacyStore: checking deletion")
        try await store.deleteUser(id:uid)
        let value8=try await ref.getDocument().exists;XCTAssertFalse(value8)
        for name in ["loginHistory","notifications","scheduledNotifs"] {let value9=try await ref.collection(name).getDocuments().isEmpty;XCTAssertTrue(value9)}
        // Preserve the exact old deletion scope, then clean up this test's retained progress.
        let value10=try await ref.collection("correctCards").document(progressID).getDocument().exists;XCTAssertTrue(value10)
        try await ref.collection("correctCards").document(progressID).delete()
    }
}
