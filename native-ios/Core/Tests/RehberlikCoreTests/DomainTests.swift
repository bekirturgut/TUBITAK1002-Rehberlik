import XCTest
@testable import RehberlikCore
final class DomainTests: XCTestCase {
    func testTurkishPhoneFormatsAgree() throws {
        for input in ["0532 123 45 67", "5321234567", "905321234567", "+90 (532) 123-45-67", "00905321234567"] {
            XCTAssertEqual(try PhoneNumber.normalize(input), "+905321234567")
        }
    }
    func testInvalidPhonesRejected() {
        for value in ["", "abc", "123", "+0123456789", "+905321234567x"] { XCTAssertThrowsError(try PhoneNumber.normalize(value)) }
    }
    func testWeekBoundariesAndFutureDates() {
        let start=Date(timeIntervalSince1970: 0)
        XCTAssertEqual(LearningPolicy.currentWeek(createdAt:start,now:start.addingTimeInterval(604799)),1)
        XCTAssertEqual(LearningPolicy.currentWeek(createdAt:start,now:start.addingTimeInterval(604800)),2)
        XCTAssertEqual(LearningPolicy.currentWeek(createdAt:start,now:start.addingTimeInterval(-1)),1)
    }
    func testEligibilityAndFourUniqueOptions() throws {
        var cards=(1...8).map { LearningCard(id:"\($0)",question:"S\($0)",answer:"C\($0)") }
        cards += [LearningCard(id:"future",question:"S",answer:"C",startWeek:3),LearningCard(id:"inactive",question:"S",answer:"C",active:false)]
        let eligible=LearningPolicy.eligible(cards,week:1); XCTAssertEqual(eligible.count,8)
        var random=SystemRandomNumberGenerator()
        for _ in 0..<50 { for q in try LearningPolicy.questions(eligible,using:&random) {
            XCTAssertEqual(Set(q.options).count,4); XCTAssertEqual(q.options.filter{$0==q.card.answer}.count,1)
        } }
    }
    func testInsufficientDistinctAnswers() {
        var random=SystemRandomNumberGenerator()
        XCTAssertThrowsError(try LearningPolicy.questions((1...4).map { LearningCard(id:"\($0)",question:"S",answer:"same") },using:&random))
    }
    func testLegacyWhitespaceIsNormalizedLikeServerGrading() {
        let card=LearningCard(id:"legacy",question:" Soru \n",answer:" Cevap \n")
        XCTAssertEqual(card.question,"Soru");XCTAssertEqual(card.answer,"Cevap")
        var random=SystemRandomNumberGenerator()
        let cards=["same"," same","same ","\nsame"].enumerated().map {LearningCard(id:String($0.offset),question:"Q",answer:$0.element)}
        XCTAssertThrowsError(try LearningPolicy.questions(cards,using:&random))
    }
    func testStatsExcludeDeletedCardsAndFloorThresholds() {
        let cards=(1...201).map { LearningCard(id:"\($0)",question:"S",answer:"C") }
        let summary=QuizSummary(cards:cards,correct:Set((1...50).map(String.init)+["deleted"]),wrong:["1","51","deleted"])
        XCTAssertEqual(summary.correctCount,50); XCTAssertEqual(summary.wrongCount,1)
        XCTAssertEqual(summary.percent,24); XCTAssertEqual(summary.earnedBadges,[])
    }
    func testEarnedBadgesPersistAndEmptyStatsAreSafe() {
        let summary=QuizSummary(cards:[],correct:["deleted"],wrong:[],previouslyEarned:[50,25,999])
        XCTAssertEqual(summary.percent,0); XCTAssertEqual(summary.earnedBadges,[25,50])
    }
    func testAdminHasNoLearningCollection() { XCTAssertNil(UserRole.admin.cardCollection) }
}
