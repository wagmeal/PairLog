import Foundation

struct RecordItem: Identifiable, Equatable {
    let id: UUID

    // Firestore のドキュメントID（編集・削除に使用）
    let firestoreDocumentID: String?

    // 誰が支払ったか（"user1" or "user2"）
    let payerUserKey: String

    // 金額
    let amount: Int

    // 何に使ったか
    let title: String

    // user1 / user2 の負担割合（合計100）
    let user1Ratio: Int
    let user2Ratio: Int

    // 費用カテゴリ
    let category: String

    // 支払日
    let date: Date

    // 過去レコードかどうか（精算済みフラグ）
    let isArchived: Bool

    // 共用支出フラグ（立て替えなし・グラフのみ反映）
    let isShared: Bool

    init(
        id: UUID = UUID(),
        firestoreDocumentID: String? = nil,
        payerUserKey: String,
        amount: Int,
        title: String,
        user1Ratio: Int,
        user2Ratio: Int,
        category: String,
        date: Date,
        isArchived: Bool = false,
        isShared: Bool = false
    ) {
        self.id = id
        self.firestoreDocumentID = firestoreDocumentID
        self.payerUserKey = payerUserKey
        self.amount = amount
        self.title = title
        self.user1Ratio = user1Ratio
        self.user2Ratio = user2Ratio
        self.category = category
        self.date = date
        self.isArchived = isArchived
        self.isShared = isShared
    }

    static func == (lhs: RecordItem, rhs: RecordItem) -> Bool {
        lhs.id == rhs.id
    }
}


