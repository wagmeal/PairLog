//
//  RegisterView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/12.
//

import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {
            Text("アカウント作成")
                .font(.largeTitle)
                .bold()

            // ログイン情報セクション
            VStack(alignment: .leading, spacing: 12) {
                Text("ログイン情報")
                    .font(.headline)

                TextField("メールアドレス", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .dismissOnSubmit()

                SecureField("パスワード", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .dismissOnSubmit()

                SecureField("パスワード（確認）", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .dismissOnSubmit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                Task {
                    await register()
                }
            }) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("アカウントを作成")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.maincolor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty || confirmPassword.isEmpty)

            Button("ログイン画面に戻る") {
                dismiss()
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // ← ここ追加
        .padding(.horizontal)
        .padding(.top, 16)   // 好きな量だけ上の余白（なければ消してOK）
        .padding(.bottom)
        .background(Color.background)
        .ignoresSafeArea(edges: .bottom)
        .dismissKeyboardToolbar()
    }

    private func register() async {
        errorMessage = nil

        guard password == confirmPassword else {
            errorMessage = "パスワードが一致しません"
            return
        }

        isLoading = true
        do {
            try await authVM.signUp(
                email: email,
                password: password
            )
        } catch {
            errorMessage = "登録に失敗しました：\(error.localizedDescription)"
        }
        isLoading = false
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthViewModel())
}
