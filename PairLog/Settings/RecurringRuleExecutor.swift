import Foundation
import FirebaseAuth
import FirebaseFirestore

/// アプリ起動時に呼び出し、当月まだ未登録の定期ルールを自動実行する
enum RecurringRuleExecutor {
    static func checkAndExecute() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let calendar = Calendar.current
        let today = Date()
        let currentYear = calendar.component(.year, from: today)
        let currentMonth = calendar.component(.month, from: today)
        let currentDay = calendar.component(.day, from: today)
        let currentYM = String(format: "%04d-%02d", currentYear, currentMonth)

        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("recurring_rules")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()

            for doc in snapshot.documents {
                let d = doc.data()
                guard
                    let dayOfMonth = d["dayOfMonth"] as? Int,
                    let payerUserKey = d["payerUserKey"] as? String,
                    let amount = d["amount"] as? Int,
                    let user1Ratio = d["user1Ratio"] as? Int,
                    let user2Ratio = d["user2Ratio"] as? Int
                else { continue }

                // 当月すでに実行済みならスキップ
                let lastExecutedYM = d["lastExecutedYearMonth"] as? String
                if lastExecutedYM == currentYM { continue }

                // 当月の実行日を計算（月末を超えないようにClamp）
                let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 28
                let targetDay = min(dayOfMonth, daysInMonth)

                // 今日が実行日を過ぎていなければスキップ
                if currentDay < targetDay { continue }

                // 実行日の日付オブジェクトを生成
                var components = DateComponents()
                components.year = currentYear
                components.month = currentMonth
                components.day = targetDay
                let payDate = calendar.date(from: components) ?? today

                let memo = d["memo"] as? String ?? ""
                let category = d["category"] as? String ?? "未分類"
                let isShared = d["isShared"] as? Bool ?? false

                if isShared {
                    // 共用費レコードを作成
                    let half = amount / 2
                    try await db.collection("users").document(uid)
                        .collection("records").addDocument(data: [
                            "payerUserKey":     "shared",
                            "amount":           amount,
                            "memo":             memo,
                            "category":         category,
                            "user1Ratio":       50,
                            "user2Ratio":       50,
                            "user1ShareAmount": half,
                            "user2ShareAmount": amount - half,
                            "payDate":          Timestamp(date: payDate),
                            "isArchived":       false,
                            "isShared":         true,
                            "createdAt":        FieldValue.serverTimestamp(),
                            "updatedAt":        FieldValue.serverTimestamp()
                        ])
                } else {
                    // 立て替えレコードを作成
                    let user1ShareAmount = Int(round(Double(amount) * Double(user1Ratio) / 100.0))
                    let user2ShareAmount = amount - user1ShareAmount
                    try await db.collection("users").document(uid)
                        .collection("records").addDocument(data: [
                            "payerUserKey":     payerUserKey,
                            "amount":           amount,
                            "memo":             memo,
                            "category":         category,
                            "user1Ratio":       user1Ratio,
                            "user2Ratio":       user2Ratio,
                            "user1ShareAmount": user1ShareAmount,
                            "user2ShareAmount": user2ShareAmount,
                            "payDate":          Timestamp(date: payDate),
                            "isArchived":       false,
                            "createdAt":        FieldValue.serverTimestamp(),
                            "updatedAt":        FieldValue.serverTimestamp()
                        ])
                }

                // 実行済みとしてマーク
                try await db.collection("users").document(uid)
                    .collection("recurring_rules").document(doc.documentID)
                    .updateData([
                        "lastExecutedYearMonth": currentYM,
                        "updatedAt": FieldValue.serverTimestamp()
                    ])

                print("✅ [RecurringRuleExecutor] 実行: \(memo.isEmpty ? category : memo) / \(currentYM)")
            }
        } catch {
            print("⚠️ [RecurringRuleExecutor] error: \(error.localizedDescription)")
        }
    }
}
