import SwiftUI

struct RecurringRuleEditView: View {
    @Environment(\.dismiss) private var dismiss
    let vm: RecurringRulesViewModel
    let editingRule: RecurringRuleItem?

    @State private var dayOfMonth: Int = 1
    @State private var payerIndex: Int = 0
    @State private var amountText: String = ""
    @State private var memoText: String = ""
    @State private var selectedCategory: String = ""
    @State private var splitRatioSliderValue: Double = 5
    @State private var splitRatioStep: Int = 5
    @State private var isActive: Bool = true
    @State private var isShared: Bool = false
    @State private var showCategorySheet = false
    @State private var isSaving = false

    private var categoryOptions: [String] {
        vm.categories.isEmpty ? ["未分類"] : vm.categories
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        recordTypeSection
                        daySection
                        if !isShared {
                            payerSection
                            ratioSection
                        }
                        amountSection
                        memoSection
                        categorySection
                        if editingRule != nil {
                            activeToggleSection
                        }
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(editingRule == nil ? "定期入力を追加" : "定期入力を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.maincolor)
                }
            }
        }
        .sheet(isPresented: $showCategorySheet) {
            categoryPickerSheet
        }
        .onAppear { loadInitialValues() }
    }

    // MARK: - Sections

    private var recordTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("種別")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.maincolor)
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                ForEach([(false, "立て替え"), (true, "共用費")], id: \.0) { shared, label in
                    Button {
                        isShared = shared
                    } label: {
                        Text(label)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(isShared == shared ? Color.background : Color.maincolor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isShared == shared ? Color.maincolor : Color.clear)
                            .animation(.easeInOut(duration: 0.15), value: isShared)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.maincolor.opacity(0.3), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var daySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("実行日")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.maincolor)
                .padding(.horizontal, 4)

            Picker("日", selection: $dayOfMonth) {
                ForEach(1...31, id: \.self) { day in
                    Text("毎月 \(day) 日").tag(day)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .clipped()
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.maincolor.opacity(0.3), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var payerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("立て替えた人")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.maincolor)
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                ForEach([0, 1], id: \.self) { idx in
                    let name = idx == 0 ? vm.user1Name : vm.user2Name
                    Button {
                        payerIndex = idx
                    } label: {
                        Text(name)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(payerIndex == idx ? Color.background : Color.maincolor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(payerIndex == idx ? Color.maincolor : Color.clear)
                            .animation(.easeInOut(duration: 0.15), value: payerIndex)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.maincolor.opacity(0.3), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
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
                        let snapped = max(0, min(10, round(splitRatioSliderValue)))
                        splitRatioSliderValue = snapped
                        splitRatioStep = Int(snapped)
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
            TextField("内容を記入", text: $memoText)
                .foregroundStyle(Color.maincolor)
                .font(.system(size: 16, weight: .semibold))
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カテゴリ")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.maincolor)
                .padding(.horizontal, 4)

            Button {
                showCategorySheet = true
            } label: {
                HStack {
                    Text(selectedCategory.isEmpty ? (categoryOptions.first ?? "未分類") : selectedCategory)
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
        }
    }

    private var activeToggleSection: some View {
        Toggle(isOn: $isActive) {
            Text("有効")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.maincolor)
        }
        .tint(Color.maincolor)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.maincolor.opacity(0.3), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var saveButton: some View {
        Button {
            guard canSave, !isSaving else { return }
            isSaving = true
            Task {
                let u1Ratio = (10 - splitRatioStep) * 10
                let u2Ratio = splitRatioStep * 10
                let payerKey = payerIndex == 0 ? "user1" : "user2"
                let amount = Int(amountText) ?? 0
                let cat = selectedCategory.isEmpty ? (categoryOptions.first ?? "未分類") : selectedCategory

                if let rule = editingRule {
                    await vm.updateRule(
                        rule,
                        dayOfMonth: dayOfMonth,
                        payerUserKey: payerKey,
                        amount: amount,
                        memo: memoText,
                        category: cat,
                        user1Ratio: u1Ratio,
                        user2Ratio: u2Ratio,
                        isActive: isActive,
                        isShared: isShared
                    )
                } else {
                    await vm.addRule(
                        dayOfMonth: dayOfMonth,
                        payerUserKey: payerKey,
                        amount: amount,
                        memo: memoText,
                        category: cat,
                        user1Ratio: u1Ratio,
                        user2Ratio: u2Ratio,
                        isShared: isShared
                    )
                }
                dismiss()
            }
        } label: {
            Text("保存")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(canSave ? Color.background : Color.background.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.maincolor.opacity(canSave ? 1.0 : 0.45))
                .clipShape(RoundedRectangle(cornerRadius: 26))
        }
        .disabled(!canSave)
        .padding(.top, 8)
    }

    private var categoryPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("カテゴリ", selection: $selectedCategory) {
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
                    Button("完了") { showCategorySheet = false }
                        .foregroundStyle(Color.maincolor)
                }
            }
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(18)
    }

    // MARK: - Helpers

    private var canSave: Bool {
        (Int(amountText) ?? 0) > 0
    }

    private var ratioText: String {
        "\((10 - splitRatioStep) * 10)：\(splitRatioStep * 10)"
    }

    private func loadInitialValues() {
        if let rule = editingRule {
            dayOfMonth = rule.dayOfMonth
            payerIndex = rule.payerUserKey == "user2" ? 1 : 0
            amountText = String(rule.amount)
            memoText = rule.memo
            selectedCategory = rule.category
            splitRatioStep = rule.user2Ratio / 10
            splitRatioSliderValue = Double(splitRatioStep)
            isActive = rule.isActive
            isShared = rule.isShared
        } else {
            selectedCategory = categoryOptions.first ?? "未分類"
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
}
