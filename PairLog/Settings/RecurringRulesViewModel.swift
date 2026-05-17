import SwiftUI
import Combine
import FirebaseAuth
import Combine
import FirebaseFirestore

@MainActor
final class RecurringRulesViewModel: ObservableObject {
    @Published private(set) var rules: [RecurringRuleItem] = []
    @Published private(set) var categories: [String] = []
    @Published private(set) var user1Name: String = "ユーザー1"
    @Published private(set) var user2Name: String = "ユーザー2"
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        Task {
            await fetchPairProfile(uid: uid)
            await fetchCategories(uid: uid)
        }

        listener?.remove()
        listener = db.collection("users").document(uid)
            .collection("recurring_rules")
            .order(by: "dayOfMonth")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("⚠️ [RecurringRulesVM] listener error: \(error)")
                    return
                }
                self.rules = snapshot?.documents.compactMap { doc -> RecurringRuleItem? in
                    let d = doc.data()
                    guard
                        let dayOfMonth = d["dayOfMonth"] as? Int,
                        let payerUserKey = d["payerUserKey"] as? String,
                        let amount = d["amount"] as? Int,
                        let user1Ratio = d["user1Ratio"] as? Int,
                        let user2Ratio = d["user2Ratio"] as? Int
                    else { return nil }
                    return RecurringRuleItem(
                        id: UUID(),
                        firestoreDocumentID: doc.documentID,
                        dayOfMonth: dayOfMonth,
                        payerUserKey: payerUserKey,
                        amount: amount,
                        memo: d["memo"] as? String ?? "",
                        category: d["category"] as? String ?? "未分類",
                        user1Ratio: user1Ratio,
                        user2Ratio: user2Ratio,
                        isActive: d["isActive"] as? Bool ?? true,
                        isShared: d["isShared"] as? Bool ?? false,
                        lastExecutedYearMonth: d["lastExecutedYearMonth"] as? String
                    )
                } ?? []
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    private func fetchPairProfile(uid: String) async {
        do {
            let doc = try await db.collection("users").document(uid)
                .collection("pair_profile").document("main").getDocument()
            let d = doc.data() ?? [:]
            user1Name = (d["user1Name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "ユーザー1"
            user2Name = (d["user2Name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "ユーザー2"
        } catch {
            print("⚠️ [RecurringRulesVM] fetchPairProfile error: \(error)")
        }
    }

    private func fetchCategories(uid: String) async {
        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("categories").order(by: "order").getDocuments()
            let fetched = snapshot.documents.compactMap { $0.data()["name"] as? String }
            categories = fetched.isEmpty ? ["未分類"] : fetched
        } catch {
            categories = ["未分類"]
        }
    }

    func addRule(
        dayOfMonth: Int,
        payerUserKey: String,
        amount: Int,
        memo: String,
        category: String,
        user1Ratio: Int,
        user2Ratio: Int,
        isShared: Bool
    ) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await db.collection("users").document(uid)
                .collection("recurring_rules").addDocument(data: [
                    "dayOfMonth": dayOfMonth,
                    "payerUserKey": payerUserKey,
                    "amount": amount,
                    "memo": memo,
                    "category": category,
                    "user1Ratio": user1Ratio,
                    "user2Ratio": user2Ratio,
                    "isShared": isShared,
                    "isActive": true,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateRule(
        _ rule: RecurringRuleItem,
        dayOfMonth: Int,
        payerUserKey: String,
        amount: Int,
        memo: String,
        category: String,
        user1Ratio: Int,
        user2Ratio: Int,
        isActive: Bool,
        isShared: Bool
    ) async {
        guard let uid = Auth.auth().currentUser?.uid,
              let docID = rule.firestoreDocumentID else { return }
        do {
            try await db.collection("users").document(uid)
                .collection("recurring_rules").document(docID).updateData([
                    "dayOfMonth": dayOfMonth,
                    "payerUserKey": payerUserKey,
                    "amount": amount,
                    "memo": memo,
                    "category": category,
                    "user1Ratio": user1Ratio,
                    "user2Ratio": user2Ratio,
                    "isShared": isShared,
                    "isActive": isActive,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteRule(_ rule: RecurringRuleItem) async {
        guard let uid = Auth.auth().currentUser?.uid,
              let docID = rule.firestoreDocumentID else { return }
        do {
            try await db.collection("users").document(uid)
                .collection("recurring_rules").document(docID).delete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func nameFor(userKey: String) -> String {
        userKey == "user1" ? user1Name : user2Name
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
