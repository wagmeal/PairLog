import SwiftUI

// MARK: - Destination

enum SettingsDestination: Hashable {
    case profile
    case category
    case recurring
}

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showLogoutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var deleteAccountErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                // MARK: Profile
                Section("プロフィール") {
                    NavigationLink(value: SettingsDestination.profile) {
                        SettingsRow(
                            icon: "person.crop.circle",
                            title: "ユーザー名・画像の編集",
                            subtitle: "2人分のユーザー情報を編集"
                        )
                    }
                }

                // MARK: Categories
                Section("記録カテゴリ") {
                    NavigationLink(value: SettingsDestination.category) {
                        SettingsRow(
                            icon: "list.bullet",
                            title: "カテゴリ管理",
                            subtitle: "追加・削除・並び替え"
                        )
                    }
                }

                // MARK: Recurring
                Section("定期入力") {
                    NavigationLink(value: SettingsDestination.recurring) {
                        SettingsRow(
                            icon: "calendar.badge.plus",
                            title: "定期入力の管理",
                            subtitle: "毎月自動で記録を登録"
                        )
                    }
                }

                // MARK: Legal
                Section("法的情報") {
                    Link(destination: URL(string: "https://sites.google.com/view/pairlog/%E3%83%9B%E3%83%BC%E3%83%A0")!) {
                        SettingsRow(
                            icon: "doc.text",
                            title: "プライバシーポリシー",
                            subtitle: "個人情報の取り扱いについて"
                        )
                    }
                }

                // MARK: Logout
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("ログアウト")
                                .font(.body)
                            Spacer()
                        }
                    }
                }

                // MARK: Delete Account
                Section {
                    Button(role: .destructive) {
                        showDeleteAccountConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("アカウントを削除")
                                .font(.body)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.maincolor)
                }
            }
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .profile:
                    PairUsersSetupView(mode: .edit)

                case .category:
                    CategoryManagementView()

                case .recurring:
                    RecurringRulesView()
                }
            }
            .alert("ログアウトしますか？", isPresented: $showLogoutConfirm) {
                Button("ログアウト", role: .destructive) {
                    try? authVM.signOut()
                }
                Button("キャンセル", role: .cancel) {}
            }
            .alert("アカウントを削除しますか？", isPresented: $showDeleteAccountConfirm) {
                Button("削除する", role: .destructive) {
                    Task {
                        do {
                            try await authVM.deleteAccount()
                        } catch {
                            deleteAccountErrorMessage = error.localizedDescription
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("アカウントおよびすべての記録データが完全に削除されます。この操作は取り消せません。")
            }
            .alert("削除できませんでした", isPresented: .init(
                get: { deleteAccountErrorMessage != nil },
                set: { if !$0 { deleteAccountErrorMessage = nil } }
            )) {
                Button("OK") { deleteAccountErrorMessage = nil }
            } message: {
                Text(deleteAccountErrorMessage ?? "")
            }
        }
    }
}

// MARK: - Row UI

private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 28)
                .foregroundStyle(Color.maincolor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.maincolor)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.maincolor.opacity(0.7))
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    SettingsView()
}
