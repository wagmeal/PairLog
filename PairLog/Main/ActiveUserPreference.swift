import Foundation
import Combine

/// アプリを操作しているユーザー（user1 / user2）の選択を UserDefaults に永続化するクラス
final class ActiveUserPreference: ObservableObject {
    @Published var activeUserKey: String {
        didSet {
            UserDefaults.standard.set(activeUserKey, forKey: "activeUserKey")
        }
    }

    init() {
        self.activeUserKey = UserDefaults.standard.string(forKey: "activeUserKey") ?? "user1"
    }
}
