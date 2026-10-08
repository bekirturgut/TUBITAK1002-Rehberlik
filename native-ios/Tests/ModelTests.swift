import XCTest
import FirebaseFirestore
import RehberlikCore
@testable import Rehberlik
final class ModelTests:XCTestCase {
    func testUnknownRoleRejectedAndLegacyMissingDateAllowed() {
        XCTAssertThrowsError(try UserProfile(id:"x",data:["role":"root","createdAt":Timestamp(date:Date())]))
        XCTAssertNoThrow(try UserProfile(id:"x",data:["role":"Anne"]))
    }
    func testNativeMigrationFlagsDoNotChangeLegacyProfile() throws {
        let profile=try UserProfile(id:"x",data:["role":"Anne","createdAt":Timestamp(date:Date()),"deleting":true])
        XCTAssertFalse(profile.disabled)
    }
    func testLegacyCardFieldMapping() {
        let item=ContentRecord(id:"1",collection:"MotherLearnCard",data:["bilinen":"Soru","gercek":"Cevap","startWeek":2,"isActive":false])
        XCTAssertEqual(item.card.question,"Soru");XCTAssertEqual(item.card.answer,"Cevap");XCTAssertEqual(item.card.startWeek,2);XCTAssertFalse(item.card.active)
    }
}
