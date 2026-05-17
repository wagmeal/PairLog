import SwiftUI

struct RecurringRulesView: View {
    @StateObject private var vm = RecurringRulesViewModel()
    @State private var showAddSheet = false
    @State private var editingRule: RecurringRuleItem?

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            if vm.rules.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(vm.rules) { rule in
                        RecurringRuleRow(rule: rule, vm: vm)
                            .contentShape(Rectangle())
                            .onTapGesture { editingRule = rule }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await vm.deleteRule(rule) }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.white)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("定期入力")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.maincolor)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            RecurringRuleEditView(vm: vm, editingRule: nil)
        }
        .sheet(item: $editingRule) { rule in
            RecurringRuleEditView(vm: vm, editingRule: rule)
        }
        .onAppear { vm.startListening() }
        .onDisappear { vm.stopListening() }
        .alert("エラー", isPresented: .init(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Color.maincolor.opacity(0.35))
            Text("定期入力がありません")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.maincolor.opacity(0.6))
            Text("毎月指定日に自動で記録を登録できます")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.maincolor.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct RecurringRuleRow: View {
    let rule: RecurringRuleItem
    let vm: RecurringRulesViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("毎月 \(rule.dayOfMonth) 日")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.maincolor)

                    if !rule.isActive {
                        Text("停止中")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.gray.opacity(0.5)))
                    }
                }

                Text(rowSubtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.maincolor.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Text("¥\(rule.amount.formatted(.number.grouping(.automatic)))")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.maincolor)
        }
        .padding(.vertical, 6)
        .opacity(rule.isActive ? 1 : 0.5)
    }

    private var rowSubtitle: String {
        let label = rule.memo.isEmpty ? rule.category : rule.memo
        if rule.isShared {
            return "\(label)　共用費"
        } else {
            return "\(label)　\(vm.nameFor(userKey: rule.payerUserKey))が立替"
        }
    }
}
