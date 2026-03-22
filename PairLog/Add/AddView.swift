import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

/// 支払った人の表示用モデル（UI用）
struct PayerDisplay: Identifiable {
    let id: Int
    let name: String
    let imageName: String
    var avatarImage: UIImage? = nil
}

struct AddView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showSettings: Bool
    @StateObject private var addVM = AddRecordViewModel()
    @State private var showSaveErrorAlert: Bool = false

    let payers: [PayerDisplay]
    let editingRecord: RecordItem?

    init(
        showSettings: Binding<Bool>,
        payers: [PayerDisplay] = MockData.payers,
        editingRecord: RecordItem? = nil
    ) {
        self._showSettings = showSettings
        self.payers = payers
        self.editingRecord = editingRecord
    }

    // MARK: - Input State (仮)
    @State private var selectedDate: Date = Date()
    @State private var showDateSheet: Bool = false
    @State private var showCategorySheet: Bool = false
    @State private var payerIndex: Int = 0
    @State private var splitRatioStep: Int = 5   // 0 = 左100%, 10 = 右100%（10%刻み）
    @State private var splitRatioSliderValue: Double = 5
    @State private var amountText: String = ""
    @State private var memoText: String = ""
    @State private var selectedTitle: String = ""


    var body: some View {
        NavigationStack {
        ZStack {
            // 背景
            Color.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    payerSection
                    ratioSection
                    dateSection
                    amountSection
                    memoSection
                    titleSection
                    settlementPreviewSection
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 24)

                Spacer(minLength: 0)
            }
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
        .sheet(isPresented: $showDateSheet) {
            NavigationStack {
                VStack(spacing: 0) {
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
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
                        Button("完了") {
                            showDateSheet = false
                        }
                        .foregroundStyle(Color.maincolor)
                    }
                }
            }
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(18)
        }
        .sheet(isPresented: $showCategorySheet) {
            NavigationStack {
                VStack(spacing: 0) {
                    Picker("カテゴリ", selection: $selectedTitle) {
                        ForEach(categoryOptions, id: \.self) { t in
                            Text(t).tag(t)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .padding(.vertical, 8)

                    Spacer(minLength: 0)
                }
                .navigationTitle("カテゴリ")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完了") {
                            showCategorySheet = false
                        }
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
                await addVM.fetchCategories()

                if let editingRecord {
                    selectedTitle = editingRecord.category
                    selectedDate = editingRecord.date
                    amountText = String(editingRecord.amount)
                    memoText = editingRecord.title
                    payerIndex = editingRecord.payerUserKey == "user2" ? 1 : 0
                    splitRatioStep = editingRecord.user2Ratio / 10
                    splitRatioSliderValue = Double(splitRatioStep)
                } else {
                    if selectedTitle.isEmpty {
                        selectedTitle = categoryOptions.first ?? "未分類"
                    }
                    splitRatioSliderValue = Double(splitRatioStep)
                }

                if !selectedTitle.isEmpty, !categoryOptions.contains(selectedTitle) {
                    selectedTitle = categoryOptions.first ?? selectedTitle
                }
            }
        }
        .alert("保存に失敗しました", isPresented: $showSaveErrorAlert) {
            Button("OK") { }
        } message: {
            Text(addVM.lastErrorMessage ?? "ネットワーク状況やログイン状態を確認してください")
        }
    }

    // MARK: - Sections
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("支払日")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.maincolor)

            VStack(spacing: 10) {
                Button {
                    showDateSheet = true
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.maincolor)

                        Text(formattedDate(selectedDate))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.maincolor)

                        Spacer()

                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
    private var payerSection: some View {
        VStack(spacing: 12) {
            Text("支払った人")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.maincolor)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 52) {
                Spacer(minLength: 0)

                ForEach(payers) { payer in
                    payerAvatar(payer: payer)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func payerAvatar(payer: PayerDisplay) -> some View {
        Button {
            payerIndex = payer.id
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(payer.imageName == "poodle" ? Color.gray : Color.subcolor1)

                    if let uiImage = payer.avatarImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 66, height: 66)
                            .clipShape(Circle())
                    } else if !payer.imageName.isEmpty {
                        Image(payer.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 66, height: 66)
                            .clipShape(Circle())
                    }
                }
                .frame(width: 74, height: 74)
                .overlay {
                    Circle()
                        .stroke(payerIndex == payer.id ? Color.maincolor : Color.maincolor.opacity(0.3), lineWidth: payerIndex == payer.id ? 2 : 1)
                }

                Text(payer.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.maincolor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(width: 86)
            }
        }
        .buttonStyle(.plain)
    }

    private var ratioSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("負担する割合")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.maincolor)

                Spacer()

                Text(ratioText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.maincolor)
            }

            Slider(
                value: $splitRatioSliderValue,
                in: 0...10,
                onEditingChanged: { isEditing in
                    if !isEditing {
                        let snappedValue = max(0, min(10, round(splitRatioSliderValue)))
                        splitRatioSliderValue = snappedValue
                        splitRatioStep = Int(snappedValue)
                    }
                }
            )
            .tint(Color.maincolor)
            .onChange(of: splitRatioSliderValue) { _, newValue in
                splitRatioStep = Int(max(0, min(10, round(newValue))))
            }
        }
    }

    private var amountSection: some View {
        fieldContainer(title: "金額") {
            TextField("0", text: $amountText)
                .keyboardType(.numberPad)
                .foregroundStyle(Color.maincolor)
                .font(.system(size: 20, weight: .semibold))
        }
    }

    private var memoSection: some View {
        fieldContainer(title: "内容") {
            TextField("内容を記入", text: $memoText, axis: .vertical)
                .lineLimit(1...4)
                .foregroundStyle(Color.maincolor)
                .font(.system(size: 16, weight: .semibold))
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

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カテゴリ")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.maincolor)
                .padding(.horizontal, 4)

            Button {
                showCategorySheet = true
            } label: {
                HStack {
                    Text(selectedTitle.isEmpty ? (categoryOptions.first ?? "未分類") : selectedTitle)
                        .foregroundStyle(Color.maincolor)
                        .font(.system(size: 18, weight: .semibold))

                    Spacer()

                    Image(systemName: "chevron.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.maincolor)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.maincolor.opacity(0.3), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if selectedTitle == "精算" {
                Text("精算カテゴリを選択したレコードはグラフに反映されません")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.maincolor.opacity(0.5))
                    .padding(.horizontal, 4)
            }
        }
    }
    private var categoryOptions: [String] {
        let fetched = addVM.categories
        return fetched.isEmpty ? ["未分類"] : fetched
    }

    private var settlementPreviewSection: some View {
        let amount = Int(amountText) ?? 0
        let user1ShareAmount = Int(round(Double(amount) * Double(10 - splitRatioStep) / 10.0))
        let user2ShareAmount = amount - user1ShareAmount
        let user1 = payers.first(where: { $0.id == 0 })
        let user2 = payers.first(where: { $0.id == 1 })
        let payer = payerIndex == 0 ? user1 : user2
        let receiver = payerIndex == 0 ? user2 : user1
        let transferAmount = payerIndex == 0 ? user2ShareAmount : user1ShareAmount
        let shouldShowPreview = payer != nil && receiver != nil && amount > 0

        return VStack(alignment: .center, spacing: 8) {
            HStack(spacing: 10) {
                if shouldShowPreview {
                    if let receiver {
                        miniPayerAvatar(receiver)
                    } else {
                        miniAvatarPlaceholder
                    }

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.maincolor)

                    if let payer {
                        miniPayerAvatar(payer)
                    } else {
                        miniAvatarPlaceholder
                    }

                    Text("￥\(transferAmount.formatted())")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.maincolor)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .center)
            .padding(.horizontal, 4)
        }
    }

    private func miniPayerAvatar(_ payer: PayerDisplay) -> some View {
        Group {
            if let uiImage = payer.avatarImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if !payer.imageName.isEmpty {
                Image(payer.imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color.subcolor1)
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.maincolor.opacity(0.25), lineWidth: 1)
        }
    }

    private var miniAvatarPlaceholder: some View {
        Circle()
            .fill(Color.clear)
            .frame(width: 34, height: 34)
            .overlay {
                Circle()
                    .stroke(Color.clear, lineWidth: 1)
            }
    }

    private func fieldContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.maincolor)
                    .padding(.horizontal, 4)
            }

            HStack {
                content()
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

    // MARK: - Actions
    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button {
                if let recordID = editingRecord?.firestoreDocumentID {
                    Task {
                        do {
                            try await addVM.deleteRecord(recordID: recordID)
                            dismiss()
                        } catch {
                            showSaveErrorAlert = true
                        }
                    }
                } else {
                    reset()
                }
            } label: {
                Text(editingRecord == nil ? "リセット" : "削除")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(editingRecord == nil ? Color.maincolor : Color.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(editingRecord == nil ? Color.maincolor.opacity(0.3) : Color.red.opacity(0.6), lineWidth: 1)
                    }
            }

            Button {
                Task {
                    do {
                        if let recordID = editingRecord?.firestoreDocumentID {
                            // 既存レコードの更新
                            try await addVM.updateRecord(
                                recordID: recordID,
                                payerUserKey: payerIndex == 0 ? "user1" : "user2",
                                user1Ratio: (10 - splitRatioStep) * 10,
                                user2Ratio: splitRatioStep * 10,
                                payDate: selectedDate,
                                amount: Int(amountText) ?? 0,
                                memo: memoText,
                                category: selectedTitle
                            )
                        } else {
                            // 新規レコードの保存
                            try await addVM.saveRecord(
                                payerUserKey: payerIndex == 0 ? "user1" : "user2",
                                user1Ratio: (10 - splitRatioStep) * 10,
                                user2Ratio: splitRatioStep * 10,
                                payDate: selectedDate,
                                amount: Int(amountText) ?? 0,
                                memo: memoText,
                                category: selectedTitle
                            )
                        }
                        dismiss()
                    } catch {
                        showSaveErrorAlert = true
                    }
                }
            } label: {
                Text("保存")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.background.opacity(canSave ? 1.0 : 0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.maincolor.opacity(canSave ? 1.0 : 0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 26))
            }
            .disabled(!canSave)
        }
        .padding(.top, 8)
    }


    private var canSave: Bool {
        let amount = Int(amountText) ?? 0
        let isValidPayerIndex = payers.contains(where: { $0.id == payerIndex })
        return amount > 0 && !selectedTitle.isEmpty && isValidPayerIndex
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    private var ratioText: String {
        let left = (10 - splitRatioStep) * 10
        let right = splitRatioStep * 10
        return "\(left)：\(right)"
    }

    private func reset() {
        selectedDate = Date()
        showDateSheet = false
        payerIndex = 0
        splitRatioStep = 5
        splitRatioSliderValue = 5
        amountText = ""
        memoText = ""
        selectedTitle = categoryOptions.first ?? "未分類"
    }
}

// MARK: - MockData
enum MockData {
    static let payers: [PayerDisplay] = [
        .init(id: 0, name: "たくみ", imageName: "user_0"),
        .init(id: 1, name: "パートナー", imageName: "user_1")
    ]
}

#Preview("新規作成") {
    AddView(showSettings: .constant(false), payers: MockData.payers, editingRecord: nil)
}

#Preview("編集") {
    AddView(
        showSettings: .constant(false),
        payers: MockData.payers,
        editingRecord: RecordsMockData.records.first
    )
}
