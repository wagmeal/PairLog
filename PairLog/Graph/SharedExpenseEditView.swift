import SwiftUI

// MARK: - Preview

#Preview {
    SharedExpenseEditView(record: RecordsMockData.sharedRecords[0])
}

// MARK: - View

struct SharedExpenseEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddRecordViewModel()

    let record: RecordItem

    @State private var amountText: String
    @State private var memoText: String
    @State private var selectedCategory: String
    @State private var selectedDate: Date
    @State private var showDateSheet = false
    @State private var showErrorAlert = false

    init(record: RecordItem) {
        self.record = record
        _amountText       = State(initialValue: "\(record.amount)")
        _memoText         = State(initialValue: record.title)
        _selectedCategory = State(initialValue: record.category)
        _selectedDate     = State(initialValue: record.date)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        dateSection
                        amountSection
                        memoSection
                        categorySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("共用支出を編集")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Color.maincolor)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            guard let id = record.firestoreDocumentID else { return }
                            do {
                                try await vm.updateSharedRecord(
                                    recordID: id,
                                    amount: Int(amountText) ?? 0,
                                    memo: memoText,
                                    category: selectedCategory,
                                    date: selectedDate
                                )
                                dismiss()
                            } catch {
                                showErrorAlert = true
                            }
                        }
                    } label: {
                        if vm.isSaving {
                            ProgressView().tint(Color.maincolor)
                        } else {
                            Text("保存")
                                .fontWeight(.semibold)
                                .foregroundStyle(canSave ? Color.maincolor : Color.maincolor.opacity(0.3))
                        }
                    }
                    .disabled(!canSave || vm.isSaving)
                }
            }
        }
        .sheet(isPresented: $showDateSheet) {
            NavigationStack {
                VStack(spacing: 0) {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
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
        .onAppear {
            Task {
                await vm.fetchCategories()
                if selectedCategory.isEmpty {
                    selectedCategory = categoryOptions.first ?? "未分類"
                }
            }
        }
        .alert("保存に失敗しました", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(vm.lastErrorMessage ?? "ネットワーク状況やログイン状態を確認してください")
        }
    }

    // MARK: - Sections

    private var dateSection: some View {
        fieldContainer(title: "支払日") {
            Button { showDateSheet = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.maincolor)
                    Text(formattedDate(selectedDate))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.maincolor)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var amountSection: some View {
        fieldContainer(title: "金額") {
            TextField("0", text: $amountText)
                .keyboardType(.numberPad)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.maincolor)
        }
    }

    private var memoSection: some View {
        fieldContainer(title: "内容") {
            TextField("内容を記入", text: $memoText, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.maincolor)
                .dismissOnSubmit()
                .onChange(of: memoText) { _, newValue in
                    if newValue.contains("\n") {
                        memoText = newValue.replacingOccurrences(of: "\n", with: "")
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カテゴリ")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.maincolor)
                .padding(.horizontal, 4)

            Menu {
                ForEach(categoryOptions, id: \.self) { cat in
                    Button(cat) { selectedCategory = cat }
                }
            } label: {
                HStack {
                    Text(selectedCategory.isEmpty ? (categoryOptions.first ?? "未分類") : selectedCategory)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.maincolor)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.maincolor.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.maincolor.opacity(0.3), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        (Int(amountText) ?? 0) > 0 && !selectedCategory.isEmpty
    }

    private var categoryOptions: [String] {
        let fetched = vm.categories.filter { $0 != "精算" }
        return fetched.isEmpty ? ["未分類"] : fetched
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }

    private func fieldContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.maincolor)
                .padding(.horizontal, 4)
            HStack { content() }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.maincolor.opacity(0.3), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
