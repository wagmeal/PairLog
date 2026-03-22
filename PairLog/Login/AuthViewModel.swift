
//
//  AuthViewModel.swift
//  PairLog
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import GoogleSignIn
import UIKit
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Preview Guard
    private nonisolated static var isRunningPreviews: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #else
        return false
        #endif
    }

    // MARK: - Published State
    @Published var user: FirebaseAuth.User?
    @Published var isLoggedIn: Bool = false

    

    // MARK: - Internal
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()

    // Sign in with Apple
    private var currentNonce: String?

    init() {
        // SwiftUI Preview では FirebaseApp.configure() が呼ばれないため FirebaseAuth を触るとクラッシュする
        if Self.isRunningPreviews {
            self.user = nil
            self.isLoggedIn = false
            return
        }

        setupAuthStateListener()
    }

    deinit {
        guard Self.isRunningPreviews == false else { return }
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    private func setupAuthStateListener() {
        guard Self.isRunningPreviews == false else { return }

        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }
                self.user = user
                self.isLoggedIn = (user != nil)
            }
        }
    }

    

    // MARK: - Email/Password
    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
        // authStateListener が状態反映
    }

    /// 登録：users/{uid} は最小限（email + terms）だけ作る
    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        try await upsertUserDoc(uid: result.user.uid, email: email)
        // authStateListener が状態反映
    }

    // MARK: - Sign in with Apple

    /// SignInWithAppleButton の onRequest で呼ぶ。nonce を生成してハッシュ値を返す
    func prepareAppleSignIn() -> String {
        let nonce = Self.randomNonceString()
        self.currentNonce = nonce
        return Self.sha256(nonce)
    }

    /// SignInWithAppleButton の onCompletion で受け取った ASAuthorization を Firebase に渡す
    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let nonce = self.currentNonce else {
            throw NSError(domain: "Auth", code: -300, userInfo: [NSLocalizedDescriptionKey: "Missing nonce."])
        }
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw NSError(domain: "Auth", code: -303, userInfo: [NSLocalizedDescriptionKey: "Invalid credential type."])
        }
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityTokenString = String(data: identityTokenData, encoding: .utf8) else {
            throw NSError(domain: "Auth", code: -301, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token."])
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: identityTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        try await upsertUserDoc(uid: authResult.user.uid, email: authResult.user.email ?? "")
    }

    // MARK: - Nonce helpers (Apple)
    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Google Sign-In
    func signInWithGoogle(presentingViewController: UIViewController) async throws {
        // presentingVC が表示中か
        guard presentingViewController.view.window != nil else {
            let msg = "presentingViewController has no window (not visible). Pass a top-most visible VC."
            throw NSError(domain: "Auth", code: -200, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        guard let app = FirebaseApp.app() else {
            let msg = "FirebaseApp.app() is nil. Did you call FirebaseApp.configure() in @main App.init()?"
            throw NSError(domain: "Auth", code: -201, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        guard let clientID = app.options.clientID, clientID.isEmpty == false else {
            let msg = "clientID not found. Check GoogleService-Info.plist Target Membership & Bundle ID match."
            throw NSError(domain: "Auth", code: -202, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let signInResult: GIDSignInResult = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                guard let result = result else {
                    cont.resume(throwing: NSError(domain: "Auth", code: -203, userInfo: [NSLocalizedDescriptionKey: "signInResult is nil"]))
                    return
                }
                cont.resume(returning: result)
            }
        }

        let gUser = signInResult.user
        guard let idToken = gUser.idToken?.tokenString, idToken.isEmpty == false else {
            throw NSError(domain: "Auth", code: -204, userInfo: [NSLocalizedDescriptionKey: "idToken is nil/empty"])
        }
        let accessToken = gUser.accessToken.tokenString

        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let authResult = try await Auth.auth().signIn(with: credential)

        // Ensure users/{uid} exists
        try await upsertUserDoc(uid: authResult.user.uid, email: authResult.user.email ?? "")
        // authStateListener が状態反映
    }

    // MARK: - Minimal user doc
    /// users/{uid} を作成/更新（PairLogは username/birthday/gender を使わない）
    private func upsertUserDoc(uid: String, email: String) async throws {
        let ref = db.collection("users").document(uid)
        let now = Timestamp(date: Date())

        let snap = try await ref.getDocument()
        if snap.exists {
            try await ref.setData([
                "email": email,
                "updatedAt": now
            ], merge: true)
        } else {
            try await ref.setData([
                "id": uid,
                "email": email,
                "createdAt": now,
                "updatedAt": now
            ])
        }
    }

    // MARK: - Account Deletion
    func deleteAccount() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ログインユーザーが見つかりません"])
        }

        let uid = currentUser.uid

        // 1) Firestore: users/{uid} と records をベストエフォートで削除
        do {
            // records サブコレクション（少量前提）
            let recordsSnap = try await db.collection("users").document(uid).collection("records").getDocuments()
            for doc in recordsSnap.documents {
                try await doc.reference.delete()
            }

            // users/{uid}
            try await db.collection("users").document(uid).delete()
        } catch {
            print("❌ Firestore データ削除でエラー: \(error.localizedDescription)")
        }

        // 2) FirebaseAuth ユーザー削除
        do {
            try await currentUser.delete()
        } catch {
            if let nsError = error as NSError?,
               let authError = AuthErrorCode(_bridgedNSError: nsError),
               authError.code == .requiresRecentLogin {
                throw NSError(
                    domain: "Auth",
                    code: nsError.code,
                    userInfo: [NSLocalizedDescriptionKey: "セキュリティのため再ログインが必要です。一度ログアウト→再ログイン後に、もう一度アカウント削除をお試しください。"]
                )
            }
            throw error
        }

        // 3) ローカル状態をリセット
        self.user = nil
        self.isLoggedIn = false
    }

    // MARK: - Sign-out
    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        self.user = nil
        self.isLoggedIn = false
    }

    func logout() {
        do {
            try signOut()
        } catch {
            print("ログアウト失敗: \(error.localizedDescription)")
        }
    }
}

// MARK: - Password reset
extension AuthViewModel {
    func sendPasswordReset(email: String) async throws {
        Auth.auth().languageCode = "ja"

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            Auth.auth().sendPasswordReset(withEmail: email) { error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }
}
