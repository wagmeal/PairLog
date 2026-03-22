import SwiftUI

// MARK: - Preview

#Preview("一覧あり") {
    SharedExpenseListView(initialRecords: RecordsMockData.sharedRecords)
}

#Preview("空") {
    SharedExpenseListView(initialRecords: [])
}

// MARK: - View

struct SharedExpenseListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddRecordViewModel()

    let initialRecords: [RecordItem]

    @State private var deletedIDs: Set<String> = []
    @State private var editingRecord: RecordItem? = nil
    @State private var recordToDelete: RecordItem? = nil
    @State private var showDeleteAlert = false
    @State private var showErrorAlert = false

    private var displayRecords: [RecordItem] {
        initialRecords
            .filter { r in
                guard let id = r.firestoreDocumentID else { return true }
                return !deletedIDs.contains(id)
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                if displayRecords.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(displayRecords) { record in
                                recordRow(record)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("共用支出の記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.maincolor)
                }
            }
        }
        .sheet(item: $editingRecord) { record in
            SharedExpenseEditView(record: record)
        }
        .alert("この記録を削除しますか？", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                guard let record = recordToDelete else { return }
                Task {
                    do {
                        if let id = record.firestoreDocumentID {
                            try await vm.deleteRecord(recordID: id)
                            withAnimation { deletedIDs.insert(id) }
                        }
                    } catch {
                        showErrorAlert = true
                    }
                    recordToDelete = nil
                }
            }
            Button("キャンセル", role: .cancel) { recordToDelete = nil }
        }
        .alert("削除に失敗しました", isPresented: $showErrorAlert) {
            Button("OK") {}
        }
    }

    // MARK: - Row

    private func recordRow(_ record: RecordItem) -> some View {
        Button { editingRecord = record } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate(record.date))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.maincolor.opacity(0.5))
                    Text(record.title.isEmpty ? "（内容なし）" : record.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.maincolor)
                        .lineLimit(1)
                    Text(record.category)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.maincolor.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.maincolor.opacity(0.08))
                        .clipShape(Capsule())
                }
                Spacer()
                Text("¥\(record.amount.formatted(.number.grouping(.automatic)))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.maincolor)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.maincolor.opacity(0.25))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.maincolor.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                recordToDelete = record
                showDeleteAlert = true
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(Color.maincolor.opacity(0.25))
            Text("共用支出の記録はありません")
                .font(.system(size: 15))
                .foregroundStyle(Color.maincolor.opacity(0.45))
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }
}
