import SwiftUI

/// カテゴリ別・ユーザー別のレコード一覧と編集ができるドリルダウン画面
struct RecordDrillDownView: View {
    let title: String
    let records: [RecordItem]
    let user1: User
    let user2: User

    @Environment(\.dismiss) private var dismiss
    @State private var editingRecord: RecordItem?
    @State private var editingSharedRecord: RecordItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        if sections.isEmpty {
                            Text("記録がありません")
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.maincolor.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                        } else {
                            ForEach(sections, id: \.dayTitle) { section in
                                Text(section.dayTitle)
                                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color.maincolor)
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity)

                                ForEach(section.items) { item in
                                    recordRow(item)

                                    if item.id != section.items.last?.id {
                                        Divider()
                                            .overlay(Color.maincolor.opacity(0.3))
                                            .padding(.leading, 16)
                                    }
                                }

                                if section.dayTitle != sections.last?.dayTitle {
                                    Divider()
                                        .overlay(Color.maincolor.opacity(0.3))
                                        .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                    .foregroundStyle(Color.maincolor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.maincolor)
                }
            }
            .sheet(item: $editingRecord) { record in
                AddView(
                    showSettings: .constant(false),
                    payers: payerDisplays,
                    editingRecord: record
                )
            }
            .sheet(item: $editingSharedRecord) { record in
                SharedExpenseEditView(record: record)
            }
        }
    }

    // MARK: - Helpers

    private var payerDisplays: [PayerDisplay] {
        [
            .init(id: 0, name: user1.name, imageName: user1.iconName, avatarImage: user1.avatarImage),
            .init(id: 1, name: user2.name, imageName: user2.iconName, avatarImage: user2.avatarImage)
        ]
    }

    private struct Section {
        let dayTitle: String
        let items: [RecordItem]
    }

    private var sections: [Section] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let grouped = Dictionary(grouping: records) { formatter.string(from: $0.date) }
        return grouped
            .map { Section(dayTitle: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.dayTitle > $1.dayTitle }
    }

    private var subTextColor: Color { Color.maincolor.opacity(0.6) }

    private func recordRow(_ item: RecordItem) -> some View {
        let detail: String = {
            if item.isShared {
                return item.category
            } else {
                let u1Share = Int(round(Double(item.amount) * Double(item.user1Ratio) / 100.0))
                let u2Share = item.amount - u1Share
                return "\(item.category)　\(user1.name)：￥\(u1Share.formatted())　\(user2.name)：￥\(u2Share.formatted())"
            }
        }()

        let payerName: String? = {
            guard !item.isShared else { return nil }
            switch item.payerUserKey {
            case "user1": return user1.name
            case "user2": return user2.name
            default: return nil
            }
        }()

        return Button {
            if item.isShared {
                editingSharedRecord = item
            } else {
                editingRecord = item
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title.isEmpty ? "（内容未記入）" : item.title)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .lineLimit(1)

                    Text(detail)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(subTextColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    if let payerName {
                        Text(payerName)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(subTextColor)
                    }

                    Text("¥\(item.amount.formatted(.number.grouping(.automatic)))")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
