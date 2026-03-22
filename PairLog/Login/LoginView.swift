import FirebaseAuth
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showResetSheet = false
    @State private var resetEmail = ""
    @State private var resetInfoMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: -18) {
                    Image("logoinvis")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                    
                    Text("PairLog")
                        .padding(.top, -24)
                        .font(.system(size: 28, weight: .semibold))
                        .italic()
                        .foregroundStyle(Color.maincolor)
                }

                TextField("メールアドレス", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .dismissOnSubmit()

                SecureField("パスワード", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .dismissOnSubmit()

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button {
                    Task { await signIn() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("ログイン")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.maincolor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                
                Button("パスワードを忘れた方") {
                    resetEmail = email
                    showResetSheet = true
                }
                .font(.footnote)
                .padding(.top, 4)
                .sheet(isPresented: $showResetSheet) {
                    NavigationStack {
                        VStack(spacing: 16) {
                            Text("パスワード再設定メールを送信します")
                                .font(.headline)

                            TextField("登録メールアドレス", text: $resetEmail)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .dismissOnSubmit()

                            if let msg = resetInfoMessage {
                                Text(msg)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }

                            Button {
                                Task {
                                    await sendReset()
                                }
                            } label: {
                                Text("メールを送信")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.maincolor)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(resetEmail.isEmpty)

                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.background)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("閉じる") { showResetSheet = false }
                            }
                        }
                        .dismissKeyboardToolbar()
                    }
                }

                HStack {
                    Rectangle().frame(height: 1).opacity(0.15)
                    Text("または")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Rectangle().frame(height: 1).opacity(0.15)
                }

                Button {
                    Task {
                        await signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image("googlelogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Googleでログイン")
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                    )
                }
                .disabled(isLoading)

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = authVM.prepareAppleSignIn()
                } onCompletion: { result in
                    Task {
                        isLoading = true
                        defer { isLoading = false }
                        switch result {
                        case .success(let authorization):
                            do {
                                try await authVM.signInWithApple(authorization: authorization)
                            } catch {
                                errorMessage = "Appleログインに失敗しました：\(error.localizedDescription)"
                            }
                        case .failure(let error):
                            errorMessage = "Appleログインに失敗しました：\(error.localizedDescription)"
                        }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .cornerRadius(10)
                .disabled(isLoading)

                NavigationLink("アカウントを作成する", destination: RegisterView())
                    .font(.footnote)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.background)
            .ignoresSafeArea(edges: .bottom)
            .dismissKeyboardToolbar()
        }
    }

    private func signIn() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await authVM.signIn(email: email, password: password)
        } catch {
            if let nsError = error as NSError?,
               let authError = AuthErrorCode(_bridgedNSError: nsError) {
                let code = authError.code

                print("🔥 Email sign-in error:", code, "/", nsError.localizedDescription)

                switch code {
                case .wrongPassword, .userNotFound:
                    errorMessage = "メールアドレスまたはパスワードが間違っています。"
                case .invalidEmail:
                    errorMessage = "メールアドレスの形式が正しくありません。"
                case .tooManyRequests:
                    errorMessage = "試行回数が多すぎます。しばらく時間をおいて再度お試しください。"
                case .networkError:
                    errorMessage = "ネットワークエラーが発生しました。通信環境を確認してください。"
                default:
                    errorMessage = "ログインに失敗しました。（コード: \(code.rawValue)）"
                }
            } else {
                errorMessage = "ログインに失敗しました：\(error.localizedDescription)"
            }
        }
    }

    private func signInWithGoogle() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        guard let vc = UIApplication.topViewController() else {
            errorMessage = "内部エラー（画面情報の取得に失敗しました）"
            return
        }

        do {
            try await authVM.signInWithGoogle(presentingViewController: vc)
        } catch {
            if let nsError = error as NSError?,
               let authError = AuthErrorCode(_bridgedNSError: nsError) {
                let code = authError.code

                print("🔥 Google sign-in error:", code, "/", nsError.localizedDescription)

                switch code {
                case .invalidCredential:
                    errorMessage = "ログイン情報が無効になっています。一度アカウントを作り直すか、別のログイン方法をお試しください。"
                case .accountExistsWithDifferentCredential:
                    errorMessage = "同じメールアドレスで別のログイン方法が登録されています。メールアドレスとパスワードでのログインをお試しください。"
                case .networkError:
                    errorMessage = "ネットワークエラーが発生しました。通信環境を確認してください。"
                default:
                    errorMessage = "Googleログインに失敗しました。（コード: \(code.rawValue)）"
                }
            } else {
                errorMessage = "Googleログインに失敗しました：\(error.localizedDescription)"
            }
        }
    }

    private func sendReset() async {
        let genericMsg = "該当するアカウントがある場合、再設定メールを送信しました。受信トレイをご確認ください。"

        do {
            try await authVM.sendPasswordReset(email: resetEmail.trimmingCharacters(in: .whitespaces))
            resetInfoMessage = genericMsg
        } catch {
            resetInfoMessage = genericMsg
            print("Password reset error:", error.localizedDescription)
        }
    }
}

extension UIApplication {
    static func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
