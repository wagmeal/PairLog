import SwiftUI
import UniformTypeIdentifiers

struct SharedExpenseAddView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddRecordViewModel()

    struct ExpenseEntry: Identifiable {
        let id = UUID()
        var amountText: String = ""
        var memo: String = ""
        var category: String = ""
        var date: Date = Date()
    }

    @State private var entries: [ExpenseEntry] = [ExpenseEntry()]
    @State private var pendingDateEntryID: UUID? = nil
    @State private var showDateSheet = false
    @State private var showErrorAlert = false
    @State private var isSavingAll = false

    @State private var isParsing = false
    @State private var parseMessage: String? = nil
    @State private var showCSVImporter = false

    var body: some View {
        NavigationStack {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    importSection

                    if isParsing {
                        parsingIndicator
                    }

                    if let msg = parseMessage {
                        parseResultBanner(msg)
                    }

                    ForEach($entries) { $entry in
                        entryCard(entry: $entry)
                    }

                    addRowButton
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showDateSheet) {
            if let idx = entries.firstIndex(where: { $0.id == pendingDateEntryID }) {
                NavigationStack {
                    VStack(spacing: 0) {
                        DatePicker("", selection: $entries[idx].date, displayedComponents: .date)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ja_JP"))
                            .padding(.vertical, 8)
                        Spacer(minLength: 0)
                    }
                    .navigationTitle("支払日")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完了") { showDateSheet = false }
                                .foregroundStyle(Color.maincolor)
                        }
                    }
                }
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(18)
            }
        }
        .onAppear {
            Task {
                await vm.fetchCategories()
                let defaultCat = categoryOptions.first ?? "未分類"
                for i in entries.indices where entries[i].category.isEmpty {
                    entries[i].category = defaultCat
                }
            }
        }
        .fileImporter(
            isPresented: $showCSVImporter,
            allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText]
        ) { result in
            Task {
                isParsing = true
                parseMessage = nil
                defer { isParsing = false }

                do {
                    let url = try result.get()
                    guard url.startAccessingSecurityScopedResource() else {
                        parseMessage = "ファイルへのアクセスができませんでした"
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }

                    let data = try Data(contentsOf: url)
                    let csvString = String(data: data, encoding: .utf8)
                        ?? String(data: data, encoding: .shiftJIS)
                        ?? ""

                    guard !csvString.isEmpty else {
                        parseMessage = "ファイルの読み込みに失敗しました"
                        return
                    }

                    let parsed = CSVParser.parse(csvString: csvString)
                    guard !parsed.isEmpty else {
                        parseMessage = "レコードが見つかりませんでした。形式を確認してください（日付,金額,内容,カテゴリ）"
                        return
                    }

                    let defaultCat = categoryOptions.first ?? "未分類"
                    let newEntries = parsed.map { record -> ExpenseEntry in
                        var e = ExpenseEntry()
                        e.amountText = "\(record.amount)"
                        e.memo = record.memo
                        e.category = record.category.isEmpty ? defaultCat : record.category
                        e.date = record.date
                        return e
                    }

                    let onlyEmpty = entries.count == 1
                        && entries[0].amountText.isEmpty && entries[0].memo.isEmpty
                    if onlyEmpty {
                        entries = newEntries
                    } else {
                        entries.append(contentsOf: newEntries)
                    }
                    parseMessage = "\(parsed.count)件を読み込みました。内容を確認してください。"
                } catch {
                    parseMessage = "CSVの読み込みに失敗しました"
                }
            }
        }
        .alert("保存に失敗しました", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(vm.lastErrorMessage ?? "ネットワーク状況やログイン状態を確認してください")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
                    .foregroundStyle(Color.maincolor)
            }
        }
        .dismissKeyboardToolbar()
        } // NavigationStack
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("共用支出を追加")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.maincolor)
            Text("共用口座からの引き落としなど、立て替えは発生しないがふたりの支出としてグラフに反映したい金額を記録します。")
                .font(.system(size: 13))
                .foregroundStyle(Color.maincolor.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Import Section

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showCSVImporter = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 16, weight: .semibold))
                    Text("CSVから読み込む")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.maincolor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isParsing)

            VStack(alignment: .leading, spacing: 3) {
                Text("CSVの形式: 日付,金額,内容,カテゴリ")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.maincolor.opacity(0.5))
                Text("例） 2024/04/01, 3800, 電気代, 光熱費")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.maincolor.opacity(0.4))
            }
            .padding(.horizontal, 4)
        }
    }

    private var parsingIndicator: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(Color.maincolor)
            Text("読み込み中...")
                .font(.system(size: 14))
                .foregroundStyle(Color.maincolor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 12)
    }

    private func parseResultBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: message.contains("見つかりません") || message.contains("失敗")
                  ? "exclamationmark.circle" : "checkmark.circle.fill")
                .font(.system(size: 15))
            Text(message)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Color.maincolor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.maincolor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Entry Card

    private func entryCard(entry: Binding<ExpenseEntry>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 金額行
            HStack(spacing: 8) {
                TextField("0", text: entry.amountText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.maincolor)
                Text("円")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.maincolor.opacity(0.5))
                Spacer()
                if entries.count > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            entries.removeAll { $0.id == entry.wrappedValue.id }
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.maincolor.opacity(0.35))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().overlay(Color.maincolor.opacity(0.12))

            // 日付行
            Button {
                pendingDateEntryID = entry.wrappedValue.id
                showDateSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.maincolor.opacity(0.6))
                    Text(formattedDate(entry.wrappedValue.date))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.maincolor)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().overlay(Color.maincolor.opacity(0.12))

            // 内容 + カテゴリ行
            HStack(spacing: 0) {
                TextField("内容を記入", text: entry.memo)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.maincolor)
                    .dismissOnSubmit()
                Spacer(minLength: 8)
                Menu {
                    ForEach(categoryOptions, id: \.self) { cat in
                        Button(cat) { entry.wrappedValue.category = cat }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(entry.wrappedValue.category.isEmpty
                             ? (categoryOptions.first ?? "未分類")
                             : entry.wrappedValue.category)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.maincolor)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.maincolor.opacity(0.5))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.maincolor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.maincolor.opacity(0.3), lineWidth: 1)
        }
    }

    // MARK: - Add Row Button

    private var addRowButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                var newEntry = ExpenseEntry()
                newEntry.category = categoryOptions.first ?? "未分類"
                entries.append(newEntry)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text("項目を追加")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.maincolor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.maincolor.opacity(0.3),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Text("キャンセル")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.maincolor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(Color.maincolor.opacity(0.3), lineWidth: 1)
                    }
            }

            Button {
                Task {
                    isSavingAll = true
                    defer { isSavingAll = false }
                    do {
                        for entry in validEntries {
                            try await vm.saveSharedRecord(
                                amount: Int(entry.amountText) ?? 0,
                                memo: entry.memo,
                                category: entry.category,
                                date: entry.date
                            )
                        }
                        dismiss()
                    } catch {
                        showErrorAlert = true
                    }
                }
            } label: {
                Text(isSavingAll ? "保存中..." : "保存")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.background.opacity(canSave ? 1.0 : 0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.maincolor.opacity(canSave ? 1.0 : 0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 26))
            }
            .disabled(!canSave || isSavingAll)
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var validEntries: [ExpenseEntry] {
        entries.filter { (Int($0.amountText) ?? 0) > 0 }
    }

    private var canSave: Bool { !validEntries.isEmpty }

    private var categoryOptions: [String] {
        let fetched = vm.categories.filter { $0 != "精算" }
        return fetched.isEmpty ? ["未分類"] : fetched
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    SharedExpenseAddView()
}
