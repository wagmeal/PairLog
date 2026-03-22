import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - Add Record ViewModel
@MainActor
final class AddRecordViewModel: ObservableObject {

    // UI state
    @Published var isSaving: Bool = false
    @Published var lastErrorMessage: String?
    @Published var categories: [String] = []
    @Published var isLoadingCategories: Bool = false

    // Dependencies
    private let db: Firestore
    private let defaultCategories: [String] = ["未分類", "日用品", "交通費", "レジャー", "食費", "精算"]

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    // MARK: - Domain
    struct RecordInput {
        let payerUserKey: String   // "user1" or "user2"
        let user1Ratio: Int        // 0...100
        let user2Ratio: Int        // 0...100
        let payDate: Date
        let amount: Int
        let memo: String
        let category: String

        init(
            payerUserKey: String,
            user1Ratio: Int,
            user2Ratio: Int,
            payDate: Date,
            amount: Int,
            memo: String,
            category: String
        ) {
            self.payerUserKey = payerUserKey
            self.user1Ratio = user1Ratio
            self.user2Ratio = user2Ratio
            self.payDate = payDate
            self.amount = amount
            self.memo = memo
            self.category = category
        }
    }

    enum SaveError: LocalizedError {
        case notLoggedIn
        case invalidAmount
        case invalidPayer
        case invalidUserKey
        case invalidRatio
        case invalidRecordID
        case deleteFailed
        case invalidCategoryName
        case categoryAlreadyExists
        case categoryDeleteFailed
        case categoryReorderFailed

        var errorDescription: String? {
            switch self {
            case .notLoggedIn:
                return "ログインが必要です"
            case .invalidAmount:
                return "金額を正しく入力してください"
            case .invalidPayer:
                return "支払った人を選択してください"
            case .invalidUserKey:
                return "支払った人の識別子が不正です"
            case .invalidRatio:
                return "割合が不正です"
            case .invalidRecordID:
                return "編集対象のレコードIDが不正です"
            case .deleteFailed:
                return "レコードの削除に失敗しました"
            case .invalidCategoryName:
                return "カテゴリ名を入力してください"
            case .categoryAlreadyExists:
                return "同じカテゴリ名がすでに存在します"
            case .categoryDeleteFailed:
                return "カテゴリの削除に失敗しました"
            case .categoryReorderFailed:
                return "カテゴリの並び替えに失敗しました"
            }
        }
    }

    private func validatedUID() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            lastErrorMessage = SaveError.notLoggedIn.localizedDescription
            throw SaveError.notLoggedIn
        }
        return uid
    }

    private func categoriesCollection(uid: String) -> CollectionReference {
        db.collection("users")
            .document(uid)
            .collection("categories")
    }

    private func normalizedCategoryName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validatedData(from input: RecordInput, includeCreatedAt: Bool) throws -> [String: Any] {
        lastErrorMessage = nil

        let payerUserKey = input.payerUserKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payerUserKey.isEmpty else {
            lastErrorMessage = SaveError.invalidPayer.localizedDescription
            throw SaveError.invalidPayer
        }

        guard payerUserKey == "user1" || payerUserKey == "user2" else {
            lastErrorMessage = SaveError.invalidUserKey.localizedDescription
            throw SaveError.invalidUserKey
        }

        guard input.amount > 0 else {
            lastErrorMessage = SaveError.invalidAmount.localizedDescription
            throw SaveError.invalidAmount
        }

        guard (0...100).contains(input.user1Ratio),
              (0...100).contains(input.user2Ratio),
              input.user1Ratio + input.user2Ratio == 100 else {
            lastErrorMessage = SaveError.invalidRatio.localizedDescription
            throw SaveError.invalidRatio
        }

        let user1ShareAmount = Int(round(Double(input.amount) * Double(input.user1Ratio) / 100.0))
        let user2ShareAmount = input.amount - user1ShareAmount

        var data: [String: Any] = [
            // who
            "payerUserKey": payerUserKey,

            // split
            "user1Ratio": input.user1Ratio,
            "user2Ratio": input.user2Ratio,

            // derived amounts (parallel users)
            "user1ShareAmount": user1ShareAmount,
            "user2ShareAmount": user2ShareAmount,

            // what/when
            "payDate": Timestamp(date: input.payDate),
            "amount": input.amount,
            "memo": input.memo,
            "category": input.category,

            // audit
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if includeCreatedAt {
            data["createdAt"] = FieldValue.serverTimestamp()
        }

        return data
    }

    func fetchCategories() async {
        do {
            try await ensureDefaultCategoriesIfNeeded()
            try await ensureSettlementCategoryExists()
            let uid = try validatedUID()

            isLoadingCategories = true
            defer { isLoadingCategories = false }

            let snapshot = try await categoriesCollection(uid: uid)
                .order(by: "order")
                .getDocuments()

            let fetched = snapshot.documents.compactMap { doc in
                doc.data()["name"] as? String
            }

            categories = fetched.isEmpty ? defaultCategories : fetched
        } catch {
            if categories.isEmpty {
                categories = defaultCategories
            }
        }
    }

    // 既存ユーザーを含め「精算」カテゴリが必ず存在するよう保証
    func ensureSettlementCategoryExists() async throws {
        let uid = try validatedUID()
        let snapshot = try await categoriesCollection(uid: uid).getDocuments()
        let existingNames = snapshot.documents.compactMap { $0.data()["name"] as? String }
        guard !existingNames.contains("精算") else { return }
        let nextOrder = (snapshot.documents.compactMap { $0.data()["order"] as? Int }.max() ?? -1) + 1
        try await categoriesCollection(uid: uid).addDocument(data: [
            "name": "精算",
            "order": nextOrder,
            "isDefault": true,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func ensureDefaultCategoriesIfNeeded() async throws {
        let uid = try validatedUID()
        let collection = categoriesCollection(uid: uid)
        let snapshot = try await collection.getDocuments()

        guard snapshot.documents.isEmpty else { return }

        for (index, category) in defaultCategories.enumerated() {
            try await collection.addDocument(data: [
                "name": category,
                "order": index,
                "isDefault": true,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }
    }

    func addCategory(_ name: String) async throws {
        let uid = try validatedUID()
        let trimmedName = normalizedCategoryName(name)

        guard !trimmedName.isEmpty else {
            lastErrorMessage = SaveError.invalidCategoryName.localizedDescription
            throw SaveError.invalidCategoryName
        }

        let lowercased = trimmedName.lowercased()
        let existingSnapshot = try await categoriesCollection(uid: uid).getDocuments()
        let existingNames = existingSnapshot.documents.compactMap { $0.data()["name"] as? String }

        if existingNames.contains(where: { $0.lowercased() == lowercased }) {
            lastErrorMessage = SaveError.categoryAlreadyExists.localizedDescription
            throw SaveError.categoryAlreadyExists
        }

        let nextOrder = existingSnapshot.documents.compactMap { $0.data()["order"] as? Int }.max().map { $0 + 1 } ?? 0

        try await categoriesCollection(uid: uid).addDocument(data: [
            "name": trimmedName,
            "order": nextOrder,
            "isDefault": false,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])

        await fetchCategories()
    }

    func deleteCategory(named name: String) async throws {
        let uid = try validatedUID()
        let trimmedName = normalizedCategoryName(name)

        guard !trimmedName.isEmpty else {
            lastErrorMessage = SaveError.invalidCategoryName.localizedDescription
            throw SaveError.invalidCategoryName
        }

        do {
            let snapshot = try await categoriesCollection(uid: uid)
                .whereField("name", isEqualTo: trimmedName)
                .getDocuments()

            for document in snapshot.documents {
                try await categoriesCollection(uid: uid)
                    .document(document.documentID)
                    .delete()
            }

            await fetchCategories()
        } catch {
            lastErrorMessage = SaveError.categoryDeleteFailed.localizedDescription
            throw error
        }
    }

    func reorderCategories(to orderedNames: [String]) async throws {
        let uid = try validatedUID()

        let normalizedNames = orderedNames
            .map { normalizedCategoryName($0) }
            .filter { !$0.isEmpty }

        guard !normalizedNames.isEmpty else { return }

        do {
            let snapshot = try await categoriesCollection(uid: uid)
                .getDocuments()

            let docsByName = Dictionary(uniqueKeysWithValues: snapshot.documents.compactMap { doc -> (String, QueryDocumentSnapshot)? in
                guard let name = doc.data()["name"] as? String else { return nil }
                return (name, doc)
            })

            let batch = db.batch()

            for (index, name) in normalizedNames.enumerated() {
                guard let doc = docsByName[name] else { continue }
                batch.updateData([
                    "order": index,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: doc.reference)
            }

            try await batch.commit()
            await fetchCategories()
        } catch {
            lastErrorMessage = SaveError.categoryReorderFailed.localizedDescription
            throw error
        }
    }

    /// users/{uid}/records/{autoId} に保存して、作成した documentID を返します
    @discardableResult
    func saveRecord(input: RecordInput) async throws -> String {
        let uid = try validatedUID()
        let data = try validatedData(from: input, includeCreatedAt: true)

        isSaving = true
        defer { isSaving = false }

        let ref = try await db
            .collection("users")
            .document(uid)
            .collection("records")
            .addDocument(data: data)

        return ref.documentID
    }

    // Backward-compatible API (既存のAddViewからそのまま呼べるように)
    @discardableResult
    func saveRecord(
        payerUserKey: String,
        user1Ratio: Int,
        user2Ratio: Int,
        payDate: Date,
        amount: Int,
        memo: String,
        category: String
    ) async throws -> String {
        try await saveRecord(
            input: RecordInput(
                payerUserKey: payerUserKey,
                user1Ratio: user1Ratio,
                user2Ratio: user2Ratio,
                payDate: payDate,
                amount: amount,
                memo: memo,
                category: category
            )
        )
    }

    @discardableResult
    func updateRecord(recordID: String, input: RecordInput) async throws -> String {
        let uid = try validatedUID()

        let trimmedRecordID = recordID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRecordID.isEmpty else {
            lastErrorMessage = SaveError.invalidRecordID.localizedDescription
            throw SaveError.invalidRecordID
        }

        let data = try validatedData(from: input, includeCreatedAt: false)

        isSaving = true
        defer { isSaving = false }

        try await db
            .collection("users")
            .document(uid)
            .collection("records")
            .document(trimmedRecordID)
            .updateData(data)

        return trimmedRecordID
    }

    @discardableResult
    func updateRecord(
        recordID: String,
        payerUserKey: String,
        user1Ratio: Int,
        user2Ratio: Int,
        payDate: Date,
        amount: Int,
        memo: String,
        category: String
    ) async throws -> String {
        try await updateRecord(
            recordID: recordID,
            input: RecordInput(
                payerUserKey: payerUserKey,
                user1Ratio: user1Ratio,
                user2Ratio: user2Ratio,
                payDate: payDate,
                amount: amount,
                memo: memo,
                category: category
            )
        )
    }

    func saveSharedRecord(amount: Int, memo: String, category: String, date: Date) async throws {
        let uid = try validatedUID()
        guard amount > 0 else {
            lastErrorMessage = SaveError.invalidAmount.localizedDescription
            throw SaveError.invalidAmount
        }
        isSaving = true
        defer { isSaving = false }
        let half = amount / 2
        try await db.collection("users").document(uid).collection("records").addDocument(data: [
            "payerUserKey":    "shared",
            "amount":          amount,
            "memo":            memo,
            "category":        category,
            "user1Ratio":      50,
            "user2Ratio":      50,
            "user1ShareAmount": half,
            "user2ShareAmount": amount - half,
            "payDate":         Timestamp(date: date),
            "isArchived":      false,
            "isShared":        true,
            "createdAt":       FieldValue.serverTimestamp(),
            "updatedAt":       FieldValue.serverTimestamp()
        ])
    }

    func updateSharedRecord(recordID: String, amount: Int, memo: String, category: String, date: Date) async throws {
        let uid = try validatedUID()
        guard amount > 0 else {
            lastErrorMessage = SaveError.invalidAmount.localizedDescription
            throw SaveError.invalidAmount
        }
        let trimmedID = recordID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else {
            lastErrorMessage = SaveError.invalidRecordID.localizedDescription
            throw SaveError.invalidRecordID
        }
        isSaving = true
        defer { isSaving = false }
        let half = amount / 2
        try await db.collection("users").document(uid).collection("records")
            .document(trimmedID)
            .updateData([
                "amount":           amount,
                "memo":             memo,
                "category":         category,
                "user1ShareAmount": half,
                "user2ShareAmount": amount - half,
                "payDate":          Timestamp(date: date),
                "updatedAt":        FieldValue.serverTimestamp()
            ])
    }

    func deleteRecord(recordID: String) async throws {
        let uid = try validatedUID()

        let trimmedRecordID = recordID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRecordID.isEmpty else {
            lastErrorMessage = SaveError.invalidRecordID.localizedDescription
            throw SaveError.invalidRecordID
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await db
                .collection("users")
                .document(uid)
                .collection("records")
                .document(trimmedRecordID)
                .delete()
        } catch {
            lastErrorMessage = SaveError.deleteFailed.localizedDescription
            throw error
        }
    }
}
