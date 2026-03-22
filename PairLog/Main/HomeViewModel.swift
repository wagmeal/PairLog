import SwiftUI
import Combine
import UIKit
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var user1: User = User(id: "user1", name: "ユーザー1", iconName: "", tint: .mint)
    @Published private(set) var user2: User = User(id: "user2", name: "ユーザー2", iconName: "", tint: .gray)
    @Published private(set) var records: [RecordItem] = []
    @Published private(set) var isLoading = true

    private let db = Firestore.firestore()
    private var recordsListener: ListenerRegistration?
    private var profileListener: ListenerRegistration?

    deinit {
        recordsListener?.remove()
        profileListener?.remove()
    }

    func start() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        setupProfileListener(uid: uid)
        setupRecordsListener(uid: uid)
    }

    // MARK: - pair_profile をリアルタイム監視

    private func setupProfileListener(uid: String) {
        profileListener = db.collection("users")
            .document(uid)
            .collection("pair_profile")
            .document("main")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("⚠️ [HomeViewModel] profile listener error: \(error.localizedDescription)")
                    return
                }
                let data = snapshot?.data() ?? [:]
                let user1Name = ((data["user1Name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let user2Name = ((data["user2Name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                // ローカルに保存されたアバター画像を読み込む
                let avatar1 = LocalAvatarStore.loadAvatar(for: .user1)
                let avatar2 = LocalAvatarStore.loadAvatar(for: .user2)

                self.user1 = User(id: "user1", name: user1Name.isEmpty ? "ユーザー1" : user1Name, iconName: "poodle", tint: .mint, avatarImage: avatar1)
                self.user2 = User(id: "user2", name: user2Name.isEmpty ? "ユーザー2" : user2Name, iconName: "pome", tint: .gray, avatarImage: avatar2)
            }
    }

    // アバター画像が更新されたとき（Firestore変化なし）に呼ぶ
    func reloadAvatars() {
        let avatar1 = LocalAvatarStore.loadAvatar(for: .user1)
        let avatar2 = LocalAvatarStore.loadAvatar(for: .user2)
        user1 = User(id: user1.id, name: user1.name, iconName: "poodle", tint: user1.tint, avatarImage: avatar1)
        user2 = User(id: user2.id, name: user2.name, iconName: "pome", tint: user2.tint, avatarImage: avatar2)
    }

    // MARK: - records をリアルタイム監視

    private func setupRecordsListener(uid: String) {
        recordsListener = db.collection("users")
            .document(uid)
            .collection("records")
            .order(by: "payDate", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("⚠️ [HomeViewModel] records listener error: \(error.localizedDescription)")
                    self.isLoading = false
                    return
                }
                if let snapshot {
                    self.records = snapshot.documents.compactMap { Self.toRecordItem(doc: $0) }
                }
                self.isLoading = false
            }
    }

    // MARK: - Firestore ドキュメント → RecordItem

    private static func toRecordItem(doc: QueryDocumentSnapshot) -> RecordItem? {
        let data = doc.data()

        guard
            let payerUserKey = data["payerUserKey"] as? String,
            let amount = data["amount"] as? Int,
            let user1Ratio = data["user1Ratio"] as? Int,
            let user2Ratio = data["user2Ratio"] as? Int,
            let category = data["category"] as? String,
            let timestamp = data["payDate"] as? Timestamp
        else { return nil }

        return RecordItem(
            firestoreDocumentID: doc.documentID,
            payerUserKey: payerUserKey,
            amount: amount,
            title: data["memo"] as? String ?? "",
            user1Ratio: user1Ratio,
            user2Ratio: user2Ratio,
            category: category,
            date: timestamp.dateValue(),
            isArchived: data["isArchived"] as? Bool ?? false,
            isShared: data["isShared"] as? Bool ?? false
        )
    }
}
