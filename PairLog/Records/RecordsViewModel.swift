import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - ViewModel
final class RecordsViewModel: ObservableObject {

    struct Section: Identifiable {
        var id: String { dayTitle }
        let dayTitle: String
        let items: [RecordItem]
    }

    private let user1: User
    private let user2: User
    @Published private(set) var records: [RecordItem]

    init(user1: User, user2: User, records: [RecordItem]) {
        self.user1 = user1
        self.user2 = user2
        self.records = records
    }

    private var activeRecords: [RecordItem] {
        records.filter { !$0.isArchived && !$0.isShared }
    }

    private var archivedRecords: [RecordItem] {
        records.filter { $0.isArchived }
    }

    var archivedRecordsForDisplay: [RecordItem] {
        archivedRecords
    }

    func updateRecords(_ newRecords: [RecordItem]) {
        records = newRecords
    }

    // 精算のみ：アクティブ記録を全アーカイブ（繰越レコードは作成しない）
    func settleOnly() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let collection = db.collection("users").document(uid).collection("records")

        let batch = db.batch()
        for record in activeRecords {
            guard let docID = record.firestoreDocumentID else { continue }
            batch.updateData(
                ["isArchived": true, "updatedAt": FieldValue.serverTimestamp()],
                forDocument: collection.document(docID)
            )
        }
        do {
            try await batch.commit()
        } catch {
            print("⚠️ [RecordsViewModel] settleOnly error: \(error.localizedDescription)")
        }
    }

    // 繰越：アクティブ記録を全アーカイブ → 残額があれば「繰越」レコードを作成
    func settleAndCarryOver() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let collection = db.collection("users").document(uid).collection("records")
        let net = netFromUser1ToUser2

        let batch = db.batch()
        for record in activeRecords {
            guard let docID = record.firestoreDocumentID else { continue }
            batch.updateData(
                ["isArchived": true, "updatedAt": FieldValue.serverTimestamp()],
                forDocument: collection.document(docID)
            )
        }

        do {
            try await batch.commit()

            if net != 0 {
                // net > 0: user1 が user2 に払う → user2 が立て替えた扱い（user1負担100%）
                // net < 0: user2 が user1 に払う → user1 が立て替えた扱い（user2負担100%）
                let payerKey  = net > 0 ? "user2" : "user1"
                let u1Ratio   = net > 0 ? 100 : 0
                let u2Ratio   = net > 0 ? 0   : 100
                let absAmount = abs(net)

                try await collection.addDocument(data: [
                    "payerUserKey":    payerKey,
                    "amount":          absAmount,
                    "memo":            "繰越",
                    "category":        "精算",
                    "user1Ratio":      u1Ratio,
                    "user2Ratio":      u2Ratio,
                    "user1ShareAmount": u1Ratio == 100 ? absAmount : 0,
                    "user2ShareAmount": u2Ratio == 100 ? absAmount : 0,
                    "payDate":         Timestamp(date: Date()),
                    "isArchived":      false,
                    "createdAt":       FieldValue.serverTimestamp(),
                    "updatedAt":       FieldValue.serverTimestamp()
                ])
            }
        } catch {
            print("⚠️ [RecordsViewModel] settle error: \(error.localizedDescription)")
        }
    }

    var sections: [Section] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"

        let grouped = Dictionary(grouping: activeRecords) {
            formatter.string(from: $0.date)
        }

        return grouped
            .map { (key, value) in
                Section(dayTitle: key, items: value.sorted { $0.date > $1.date })
            }
            .sorted { $0.dayTitle > $1.dayTitle }
    }

    var archivedSections: [Section] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"

        let grouped = Dictionary(grouping: archivedRecords) {
            formatter.string(from: $0.date)
        }

        return grouped
            .map { (key, value) in
                Section(dayTitle: key, items: value.sorted { $0.date > $1.date })
            }
            .sorted { $0.dayTitle > $1.dayTitle }
    }

    // user1 -> user2 に支払うべきなら正、逆なら負
    private var netFromUser1ToUser2: Int {
        activeRecords.reduce(0) { acc, item in
            acc + netContribution(for: item)
        }
    }

    var settlementAmount: Int {
        abs(netFromUser1ToUser2)
    }

    var settlementAmountText: String {
        if settlementAmount == 0 {
            return "¥0"
        }
        return "¥\(settlementAmount.formatted(.number.grouping(.automatic)))"
    }

    func payerName(for item: RecordItem) -> String {
        switch item.payerUserKey {
        case "user1":
            return user1.name
        case "user2":
            return user2.name
        default:
            return item.payerUserKey
        }
    }

    func recordSettlementText(for item: RecordItem) -> String {
        let transfer = transferForRecord(item)
        if transfer.amount == 0 { return "精算なし" }
        return "\(transfer.from) → \(transfer.to) ¥\(transfer.amount.formatted(.number.grouping(.automatic)))"
    }

    // user1Ratio / user2Ratio を使って各自負担額を計算
    // 返り値は user1->user2 の支払い額（正=user1が払う、負=user2が払う）
    private func netContribution(for item: RecordItem) -> Int {
        let user1Share = Int(round(Double(item.amount) * Double(item.user1Ratio) / 100.0))
        let user2Share = item.amount - user1Share

        switch item.payerUserKey {
        case "user1":
            // user2 -> user1
            return -user2Share
        case "user2":
            // user1 -> user2
            return user1Share
        default:
            return 0
        }
    }

    private func transferForRecord(_ item: RecordItem) -> (from: String, to: String, amount: Int) {
        let user1Share = Int(round(Double(item.amount) * Double(item.user1Ratio) / 100.0))
        let user2Share = item.amount - user1Share

        switch item.payerUserKey {
        case "user1":
            return (from: user2.name, to: user1.name, amount: max(0, user2Share))
        case "user2":
            return (from: user1.name, to: user2.name, amount: max(0, user1Share))
        default:
            return (from: "-", to: "-", amount: 0)
        }
    }
}
