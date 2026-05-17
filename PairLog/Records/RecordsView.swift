import SwiftUI
import Combine

struct RecordsView: View {
    @Binding var showSettings: Bool
    @State private var showNewRecordSheet: Bool = false
    @State private var selectedRecord: RecordItem?
    @State private var showPastRecordsSheet: Bool = false
    @State private var showSettlementAlert: Bool = false
    @State private var showCarryOverConfirm: Bool = false
    @State private var showSettleOnlyConfirm: Bool = false

    let user1: User
    let user2: User
    let records: [RecordItem]
    let onRefresh: (() async -> Void)?

    @StateObject private var viewModel: RecordsViewModel

    init(
        showSettings: Binding<Bool>,
        user1: User,
        user2: User,
        records: [RecordItem],
        onRefresh: (() async -> Void)? = nil
    ) {
        self._showSettings = showSettings
        self.user1 = user1
        self.user2 = user2
        self.records = records
        self.onRefresh = onRefresh
        _viewModel = StateObject(wrappedValue: RecordsViewModel(user1: user1, user2: user2, records: records))
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            VStack(spacing: 14) {
                summaryCard
                recordsHeader

                ScrollView {
                    recordsCard
                }
                .refreshable {
                    await onRefresh?()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showNewRecordSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.background)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle().fill(Color.maincolor)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 8)
                    }
                    .accessibilityLabel("追加")
                }
            }
            .padding(.trailing, 18)
            .padding(.bottom, 22)
        }
        .onChange(of: records) { _, newRecords in
            viewModel.updateRecords(newRecords)
        }
        .sheet(isPresented: $showNewRecordSheet) {
            AddView(
                showSettings: $showSettings,
                payers: payerDisplays,
                editingRecord: nil
            )
        }
        .sheet(item: $selectedRecord, onDismiss: {
            Task { await onRefresh?() }
        }) { record in
            AddView(
                showSettings: $showSettings,
                payers: payerDisplays,
                editingRecord: record
            )
        }
        .sheet(isPresented: $showPastRecordsSheet) {
            PastRecordsView(
                user1: user1,
                user2: user2,
                records: viewModel.archivedRecordsForDisplay
            )
        }
        .alert("精算方法を選んでください", isPresented: $showSettlementAlert) {
            Button("繰越") { showCarryOverConfirm = true }
            Button("精算") { showSettleOnlyConfirm = true }
            Button("キャンセル", role: .cancel) {}
        } 
        .alert("本当に繰越しますか？", isPresented: $showCarryOverConfirm) {
            Button("繰越する", role: .destructive) {
                Task { await viewModel.settleAndCarryOver() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("現在の立て替え記録を過去の記録に移し、残額を繰越レコードとして引き継ぎます。")
        }
        .alert("本当に精算しますか？", isPresented: $showSettleOnlyConfirm) {
            Button("精算する", role: .destructive) {
                Task { await viewModel.settleOnly() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("現在の立て替え記録を過去の記録に移します。残額の繰越は行わず、まっさらな状態になります。")
        }
    }

    // MARK: - Theme
    private var summaryTextColor: Color { Color.background }
    private var recordsTextColor: Color { Color.maincolor }
    private var recordsSubTextColor: Color { recordsTextColor.opacity(0.7) }
    private var recordsHeaderTextColor: Color { Color.maincolor }

    private var payerDisplays: [PayerDisplay] {
        [
            .init(id: 0, name: user1.name, imageName: user1.iconName, avatarImage: user1.avatarImage),
            .init(id: 1, name: user2.name, imageName: user2.iconName, avatarImage: user2.avatarImage)
        ]
    }

    private var summaryCard: some View {
        HStack(alignment: .center, spacing: 0) {
            // ── ユーザーアイコン ＋ 矢印 ────────────────
            HStack(spacing: 6) {
                avatarView(user: viewModel.settlementPayer)

                Text("から")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(summaryTextColor.opacity(0.85))

                avatarView(user: viewModel.settlementReceiver)

                Text("へ")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(summaryTextColor.opacity(0.85))
            }

            Spacer()

            // ── 精算金額 ──
            Text(viewModel.settlementAmountText)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(summaryTextColor)

            Spacer()

            // ── 精算ボタン ──
            Button {
                showSettlementAlert = true
            } label: {
                Text("精算")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.subcolor1.opacity(0.95)))
            }
            .disabled(viewModel.settlementAmount == 0)
            .opacity(viewModel.settlementAmount == 0 ? 0.5 : 1)
        }
        .foregroundStyle(summaryTextColor)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.maincolor)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var recordsHeader: some View {
        HStack {
            Spacer()

            Button {
                showPastRecordsSheet = true
            } label: {
                HStack(spacing: 6) {
                    Text("過去の記録を見る")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
        }
        .foregroundStyle(recordsHeaderTextColor)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var recordsCard: some View {
        VStack(spacing: 0) {
            if viewModel.sections.isEmpty {
                Text("立て替え記録がありません")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(recordsSubTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.sections) { section in
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

                        if section.id != viewModel.sections.last?.id {
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

    private func avatarView(user: User) -> some View {
        let bgColor: Color = user.iconName == "poodle" ? Color.gray : Color.subcolor1

        return Circle()
            .fill(bgColor)
            .frame(width: 34, height: 34)
            .overlay {
                if let uiImage = user.avatarImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                } else if !user.iconName.isEmpty {
                    Image(user.iconName)
                        .resizable()
                        .scaledToFit()
                        .padding(2)
                }
            }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.06))
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }
}

#Preview {
    RecordsView(
        showSettings: .constant(false),
        user1: RecordsMockData.user1,
        user2: RecordsMockData.user2,
        records: RecordsMockData.records
    )
}
