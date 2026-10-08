import Foundation
import FirebaseFirestore
import RehberlikCore

struct UserProfile: Identifiable {
    let id: String
    var name: String, surname: String, phone: String
    var role: UserRole
    var createdAt: Date
    var disabled: Bool
    var earnedBadges: [Int]
    init(id: String, data: [String: Any]) throws {
        guard let role=UserRole(rawValue: data["role"] as? String ?? ""), let created=(data["createdAt"] as? Timestamp)?.dateValue() else { throw DomainError.invalidProfile }
        self.id=id; self.role=role; createdAt=created
        name=data["name"] as? String ?? ""; surname=data["surname"] as? String ?? ""
        phone=data["phone"] as? String ?? ""; disabled=(data["disabled"] as? Bool ?? false) || (data["deleting"] as? Bool ?? false)
        earnedBadges=(data["quizStats"] as? [String:Any])?["earnedBadges"] as? [Int] ?? []
    }
    var fullName: String { "\(name) \(surname)".trimmingCharacters(in: .whitespaces) }
}
struct ContentRecord: Identifiable {
    let id: String
    let collection: String
    var data: [String: Any]
    var title: String { data["question"] as? String ?? data["bilinen"] as? String ?? data["title"] as? String ?? "İçerik" }
    var body: String { data["answer"] as? String ?? data["gercek"] as? String ?? data["body"] as? String ?? "" }
    var active: Bool { data["isActive"] as? Bool ?? true }
    var createdAt: Date { (data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast }
    var card: LearningCard { LearningCard(id:id,question:title,answer:body,startWeek:(data["startWeek"] as? NSNumber)?.intValue ?? 1,active:active) }
}
struct ChatMessage: Identifiable {
    let id: String
    let text: String, senderType: String, sourceMessageID: String?
    let createdAt: Date
    let pending: Bool, answered: Bool, needsFeedback: Bool, feedbackGiven: Bool
    init(id: String, data: [String: Any]) {
        self.id=id; text=data["text"] as? String ?? ""; senderType=data["senderType"] as? String ?? "user"
        sourceMessageID=data["sourceMessageId"] as? String
        createdAt=(data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
        pending=data["needsAdminReply"] as? Bool ?? false; answered=data["isAnswered"] as? Bool ?? false
        needsFeedback=data["needsFeedback"] as? Bool ?? false; feedbackGiven=data["feedbackGiven"] as? Bool ?? false
    }
}
struct HistoryEntry: Identifiable { let id: String; let date: Date }
struct ChatSummary: Identifiable { let id: String; let pendingCount: Int }
