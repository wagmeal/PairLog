import SwiftUI

struct PastRecordsView: View {
    let user1: User
    let user2: User
    let records: [RecordItem]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RecordsViewModel
    @State private var selectedRecord: RecordItem?

    init(
        user1: User,
        user2: User,
        records: [RecordItem]
    ) {
        self.user1 = user1
        self.user2 = user2
        self.records = records
        _viewModel = StateObject(
            wrappedValue: RecordsViewModel(
                user1: user1,
                user2: user2,
                records: records
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    recordsCard
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("過去の記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundStyle(Color.maincolor)
                }
            }
            .sheet(item: $selectedRecord) { record in
                AddView(
                    showSettings: .constant(false),
                    payers: payerDisplays,
                    editingRecord: record
                )
            }
        }
    }

    private var payerDisplays: [PayerDisplay] {
        [
            .init(id: 0, name: user1.name, imageName: user1.iconName, avatarImage: user1.avatarImage),
            .init(id: 1, name: user2.name, imageName: user2.iconName, avatarImage: user2.avatarImage)
        ]
    }

    private var recordsTextColor: Color { Color.maincolor }
    private var recordsSubTextColor: Color { recordsTextColor.opacity(0.7) }

    private var recordsCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(viewModel.archivedSections) { section in
                    Text(section.dayTitle)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
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

                    if section.id != viewModel.archivedSections.last?.id {
                        Divider()
                            .overlay(Color.maincolor.opacity(0.3))
                            .padding(.vertical, 6)
                    }
                }
            }
            .foregroundStyle(recordsTextColor)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
    }

    private func recordRow(_ item: RecordItem) -> some View {
        let user1Share = Int(round(Double(item.amount) * Double(item.user1Ratio) / 100.0))
        let user2Share = item.amount - user1Share
        let detail = "\(item.category)　\(user1.name)：￥\(user1Share.formatted())　\(user2.name)：￥\(user2Share.formatted())"

        let payerName: String = {
            switch item.payerUserKey {
            case "user1": return user1.name
            case "user2": return user2.name
            default: return ""
            }
        }()

        return Button {
            selectedRecord = item
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .lineLimit(1)

                    Text(detail)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(recordsSubTextColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    if !payerName.isEmpty {
                        Text(payerName)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(recordsSubTextColor)
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

#Preview {
    PastRecordsView(
        user1: RecordsMockData.user1,
        user2: RecordsMockData.user2,
        records: RecordsMockData.records
    )
}
