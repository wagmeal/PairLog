import SwiftUI

// MARK: - Destination

enum SettingsDestination: Hashable {
    case profile
    case category
}

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showLogoutConfirm = false

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
                }
            }
            .alert("ログアウトしますか？", isPresented: $showLogoutConfirm) {
                Button("ログアウト", role: .destructive) {
                    try? authVM.signOut()
                }
                Button("キャンセル", role: .cancel) {}
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
