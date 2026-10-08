import Foundation

public enum UserRole: String, CaseIterable, Codable, Identifiable, Sendable {
    case mother = "Anne", elder = "Üst Kuşak", admin = "Admin"
    public var id: String { rawValue }
    public var cardCollection: String? {
        switch self { case .mother: return "MotherLearnCard"; case .elder: return "UpperLearnCard"; case .admin: return nil }
    }
}
public enum DomainError: LocalizedError, Equatable {
    case invalidPhone, notEnoughAnswers, invalidProfile, invalidResponse
    public var errorDescription: String? {
        switch self {
        case .invalidPhone: return "Geçerli bir telefon numarası giriniz."
        case .notEnoughAnswers: return "Dört seçenek için en az dört farklı cevaplı açık kart gerekiyor."
        case .invalidProfile: return "Kullanıcı bilgileri eksik veya geçersiz."
        case .invalidResponse: return "Sunucudan geçersiz yanıt alındı."
        }
    }
}
public enum PhoneNumber {
    public static func normalize(_ input: String) throws -> String {
        var value = input.filter { !$0.isWhitespace && !"()-".contains($0) }
        if value.hasPrefix("00") { value = "+" + value.dropFirst(2) }
        if value.range(of: "^0[0-9]{10}$", options: .regularExpression) != nil { value = "+90" + value.dropFirst() }
        if value.range(of: "^5[0-9]{9}$", options: .regularExpression) != nil { value = "+90" + value }
        if value.range(of: "^90[0-9]{10}$", options: .regularExpression) != nil { value = "+" + value }
        guard value.range(of: "^\\+[1-9][0-9]{7,14}$", options: .regularExpression) != nil else { throw DomainError.invalidPhone }
        return value
    }
}
public struct LearningCard: Identifiable, Equatable, Sendable {
    public let id: String
    public let question: String
    public let answer: String
    public let startWeek: Int
    public let active: Bool
    public init(id: String, question: String, answer: String, startWeek: Int = 1, active: Bool = true) {
        self.id = id; self.question = question; self.answer = answer; self.startWeek = startWeek; self.active = active
    }
}
public struct QuizQuestion: Identifiable, Equatable, Sendable {
    public var id: String { card.id }
    public let card: LearningCard
    public let options: [String]
}
public enum LearningPolicy {
    public static func currentWeek(createdAt: Date, now: Date = Date()) -> Int {
        max(1, Int(floor(now.timeIntervalSince(createdAt) / (7 * 86400))) + 1)
    }
    public static func eligible(_ cards: [LearningCard], week: Int) -> [LearningCard] {
        cards.filter { $0.active && $0.startWeek <= week && !$0.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    public static func questions<R: RandomNumberGenerator>(_ cards: [LearningCard], using random: inout R) throws -> [QuizQuestion] {
        let answers = Array(Set(cards.map(\.answer)))
        guard answers.count >= 4 else { throw DomainError.notEnoughAnswers }
        return cards.map { card in
            var distractors = answers.filter { $0 != card.answer }; distractors.shuffle(using: &random)
            var options = [card.answer] + distractors.prefix(3); options.shuffle(using: &random)
            return QuizQuestion(card: card, options: options)
        }.shuffled(using: &random)
    }
}
public struct QuizSummary: Equatable, Sendable {
    public let assignedCount: Int, correctCount: Int, wrongCount: Int, percent: Int
    public let earnedBadges: [Int]
    public init(cards: [LearningCard], correct: Set<String>, wrong: Set<String>, previouslyEarned: [Int] = []) {
        let valid = Set(cards.map(\.id)); assignedCount = valid.count
        correctCount = valid.intersection(correct).count
        wrongCount = valid.intersection(wrong.subtracting(correct)).count
        percent = valid.isEmpty ? 0 : correctCount * 100 / valid.count
        let thresholds = [25, 50, 75, 100]
        earnedBadges = Array(Set(previouslyEarned.filter { thresholds.contains($0) } + thresholds.filter { percent >= $0 })).sorted()
    }
}
