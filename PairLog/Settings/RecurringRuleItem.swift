import Foundation

struct RecurringRuleItem: Identifiable, Equatable {
    let id: UUID
    let firestoreDocumentID: String?
    let dayOfMonth: Int          // 1-31
    let payerUserKey: String     // "user1" or "user2"
    let amount: Int
    let memo: String
    let category: String
    let user1Ratio: Int          // 0-100
    let user2Ratio: Int          // 0-100
    let isActive: Bool
    let isShared: Bool                  // true = 共用費、false = 立て替え
    let lastExecutedYearMonth: String?  // "yyyy-MM" 形式。当月実行済みか判定に使用

    static func == (lhs: RecurringRuleItem, rhs: RecurringRuleItem) -> Bool {
        lhs.id == rhs.id
    }
}
