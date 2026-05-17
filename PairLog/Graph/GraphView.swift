import SwiftUI
import Charts

struct GraphView: View {
    @Binding var showSettings: Bool
    let user1: User
    let user2: User
    let records: [RecordItem]
    let onRefresh: (() async -> Void)?

    @State private var selectedTab: GraphTab = .monthly
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var insertEdge: Edge = .trailing
    @State private var selectedMonth: String? = nil
    @State private var selectedYearBar: String? = nil
    @State private var showSharedExpenseSheet = false
    @State private var showSharedList = false
    @State private var drillDownItem: DrillDownItem?

    struct DrillDownItem: Identifiable {
        enum Filter {
            case category(String)
            case payer(String)  // userKey "user1" or "user2"
        }
        let id = UUID()
        let title: String
        let filter: Filter
    }

    enum GraphTab: String, CaseIterable {
        case monthly = "月別"
        case yearly  = "年別"
    }

    private static let monthLabels = (1...12).map { "\($0)月" }

    // MARK: - Year navigation

    private func goToNextYear() {
        if let next = availableYears.first(where: { $0 > selectedYear }) {
            insertEdge = .trailing
            selectedMonth = nil
            withAnimation(.easeInOut(duration: 0.3)) { selectedYear = next }
        }
    }

    private func goPrevYear() {
        if let prev = availableYears.last(where: { $0 < selectedYear }) {
            insertEdge = .leading
            selectedMonth = nil
            withAnimation(.easeInOut(duration: 0.3)) { selectedYear = prev }
        }
    }

    // MARK: - Computed data

    private var availableYears: [Int] {
        let years = Set(graphRecords.map { Calendar.current.component(.year, from: $0.date) })
        let current = Calendar.current.component(.year, from: Date())
        return Array(years.union([current])).sorted()
    }

    private var totalAmount: Int {
        graphRecords.reduce(0) { $0 + $1.amount }
    }

    private var monthlyYMax: Double {
        let max = monthlyData.map(\.amount).max() ?? 0
        return max == 0 ? 1000 : Double(max) * 1.5
    }

    private var yearlyYMax: Double {
        let max = yearlyData.map(\.amount).max() ?? 0
        return max == 0 ? 1000 : Double(max) * 1.5
    }

    // 選択年の1〜12月
    private var monthlyData: [(month: String, amount: Int)] {
        let grouped = Dictionary(grouping: graphRecords.filter {
            Calendar.current.component(.year, from: $0.date) == selectedYear
        }) {
            "\(Calendar.current.component(.month, from: $0.date))月"
        }
        return Self.monthLabels.map { label in
            (month: label, amount: grouped[label]?.reduce(0) { $0 + $1.amount } ?? 0)
        }
    }

    // 年別合計
    private var yearlyData: [(label: String, amount: Int)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        let grouped = Dictionary(grouping: graphRecords) { formatter.string(from: $0.date) }
        return grouped
            .map { (label: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.label < $1.label }
    }

    // 精算カテゴリを除いた全レコード
    private var graphRecords: [RecordItem] {
        records.filter { $0.category != "精算" }
    }

    // タブ・選択状態でフィルタされたレコード（カテゴリ/立て替え集計用）
    private var filteredRecords: [RecordItem] {
        switch selectedTab {
        case .monthly:
            let yearFiltered = graphRecords.filter {
                Calendar.current.component(.year, from: $0.date) == selectedYear
            }
            if let month = selectedMonth,
               let monthNum = Self.monthLabels.firstIndex(of: month).map({ $0 + 1 }) {
                return yearFiltered.filter {
                    Calendar.current.component(.month, from: $0.date) == monthNum
                }
            }
            return yearFiltered
        case .yearly:
            if let yearLabel = selectedYearBar {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy"
                return graphRecords.filter { formatter.string(from: $0.date) == yearLabel }
            }
            return graphRecords
        }
    }

    // グラフ上部に表示する合計
    private var displayTotal: Int {
        filteredRecords.reduce(0) { $0 + $1.amount }
    }

    private var monthlyPeriodLabel: String {
        selectedMonth ?? "合計"
    }

    private var yearlyPeriodLabel: String {
        if let year = selectedYearBar { return "\(year)年" }
        return "合計"
    }

    private var categoryData: [(category: String, amount: Int)] {
        let grouped = Dictionary(grouping: filteredRecords) { $0.category }
        return grouped
            .map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }

    private var payerData: [(user: User, amount: Int)] {
        let user1Total = filteredRecords.filter { $0.payerUserKey == "user1" }.reduce(0) { $0 + $1.amount }
        let user2Total = filteredRecords.filter { $0.payerUserKey == "user2" }.reduce(0) { $0 + $1.amount }
        return [(user: user1, amount: user1Total), (user: user2, amount: user2Total)]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Picker("", selection: $selectedTab) {
                        ForEach(GraphTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    switch selectedTab {
                    case .monthly: monthlyChart
                    case .yearly:  yearlyChart
                    }
                }

                ScrollView {
                    VStack(spacing: 12) {
                        categoryChart
                        payerChart
                        sharedRecordsNavCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .refreshable {
                    await onRefresh?()
                }
            }
        }
        .onChange(of: selectedTab) { _, _ in
            selectedMonth = nil
            selectedYearBar = nil
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showSharedExpenseSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.background)
                    .frame(width: 56, height: 56)
                    .background(Color.maincolor)
                    .clipShape(Circle())
                    .shadow(color: Color.maincolor.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showSharedExpenseSheet) {
            SharedExpenseAddView()
        }
        .sheet(isPresented: $showSharedList) {
            SharedExpenseListView(initialRecords: sharedRecords)
        }
        .sheet(item: $drillDownItem) { item in
            let liveRecords: [RecordItem] = {
                switch item.filter {
                case .category(let cat): return filteredRecords.filter { $0.category == cat }
                case .payer(let key):    return filteredRecords.filter { $0.payerUserKey == key }
                }
            }()
            RecordDrillDownView(
                title: item.title,
                records: liveRecords,
                user1: user1,
                user2: user2
            )
        }
    }

    private var sharedRecords: [RecordItem] {
        records.filter { $0.isShared }
    }

    // MARK: - 月別棒グラフ

    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("月別支出")
                        .font(.headline)
                        .foregroundColor(Color.maincolor)
                    Text(monthlyPeriodLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.maincolor.opacity(0.55))
                        .animation(.easeInOut(duration: 0.2), value: monthlyPeriodLabel)
                }
                Spacer()
                yearStepper
            }

            ZStack(alignment: .top) {
                Chart(monthlyData, id: \.month) { item in
                    BarMark(
                        x: .value("月", item.month),
                        y: .value("金額", item.amount),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(
                        selectedMonth == nil || selectedMonth == item.month
                            ? Color.maincolor
                            : Color.maincolor.opacity(0.2)
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: Self.monthLabels) { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label).font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v >= 1000 ? "¥\(Int(v / 1000))k" : "¥\(Int(v))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...monthlyYMax)
                .frame(height: 180)
                .padding(.top, 44)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(Color.clear).contentShape(Rectangle())
                            .onTapGesture { location in
                                let origin = geo[proxy.plotAreaFrame].origin
                                let xPos = location.x - origin.x
                                if let month: String = proxy.value(atX: xPos),
                                   let item = monthlyData.first(where: { $0.month == month }),
                                   item.amount > 0 {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedMonth = (selectedMonth == month) ? nil : month
                                    }
                                }
                            }
                    }
                }

                Text("¥\(displayTotal.formatted(.number.grouping(.automatic)))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.maincolor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                    .animation(.easeInOut(duration: 0.2), value: displayTotal)
            }
            .id(selectedYear)
            .transition(.asymmetric(
                insertion: .move(edge: insertEdge),
                removal: .move(edge: insertEdge == .trailing ? .leading : .trailing)
            ))
            .clipped()
        }
        .clipped()
        .padding(16)
        .background(Color.background)
        .gesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    guard abs(horizontal) > vertical else { return }
                    if horizontal < 0 { goToNextYear() } else { goPrevYear() }
                }
        )
    }

    // MARK: - 年別棒グラフ

    private var yearlyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("年別支出")
                        .font(.headline)
                        .foregroundColor(Color.maincolor)
                    Text(yearlyPeriodLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.maincolor.opacity(0.55))
                        .animation(.easeInOut(duration: 0.2), value: yearlyPeriodLabel)
                }
                Spacer()
            }

            if yearlyData.isEmpty {
                emptyView
            } else {
                ZStack(alignment: .top) {
                    Chart(yearlyData, id: \.label) { item in
                        BarMark(
                            x: .value("年", item.label),
                            y: .value("金額", item.amount),
                            width: .ratio(0.5)
                        )
                        .foregroundStyle(
                            selectedYearBar == nil || selectedYearBar == item.label
                                ? Color.maincolor
                                : Color.maincolor.opacity(0.2)
                        )
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks { _ in AxisValueLabel().font(.caption2) }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(v >= 1000 ? "¥\(Int(v / 1000))k" : "¥\(Int(v))")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...yearlyYMax)
                    .frame(height: 180)
                    .padding(.top, 44)
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(Color.clear).contentShape(Rectangle())
                                .onTapGesture { location in
                                    let origin = geo[proxy.plotAreaFrame].origin
                                    let xPos = location.x - origin.x
                                    if let year: String = proxy.value(atX: xPos) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedYearBar = (selectedYearBar == year) ? nil : year
                                        }
                                    }
                                }
                        }
                    }

                    Text("¥\(displayTotal.formatted(.number.grouping(.automatic)))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.maincolor)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                        .animation(.easeInOut(duration: 0.2), value: displayTotal)
                }
            }
        }
        .padding(16)
        .background(Color.background)
    }

    // MARK: - 年選択ボタン

    private var yearStepper: some View {
        HStack(spacing: 0) {
            Button { goPrevYear() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.maincolor)
                    .padding(6)
            }
            .disabled(!availableYears.contains(where: { $0 < selectedYear }))

            Text("\(String(selectedYear))年")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.maincolor)
                .frame(minWidth: 56, alignment: .center)

            Button { goToNextYear() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.maincolor)
                    .padding(6)
            }
            .disabled(!availableYears.contains(where: { $0 > selectedYear }))
        }
    }

    // MARK: - カテゴリ別リスト

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("カテゴリ別支出")
                .font(.headline)
                .foregroundColor(Color.maincolor)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if categoryData.isEmpty {
                emptyView
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(categoryData, id: \.category) { item in
                        Button {
                            drillDownItem = DrillDownItem(
                                title: item.category,
                                filter: .category(item.category)
                            )
                        } label: {
                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(Color.maincolor)
                                    .frame(width: 4)
                                    .cornerRadius(2)

                                Text(item.category)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(Color.maincolor)

                                Spacer()

                                HStack(spacing: 4) {
                                    Text("¥\(item.amount.formatted(.number.grouping(.automatic)))")
                                        .font(.system(.body, design: .rounded).weight(.semibold))
                                        .foregroundColor(Color.maincolor)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.maincolor.opacity(0.4))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if item.category != categoryData.last?.category {
                            Divider()
                                .overlay(Color.maincolor.opacity(0.15))
                                .padding(.leading, 32)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color.background)
        .cornerRadius(12)
    }

    // MARK: - ユーザー別立て替えリスト

    private var payerChart: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("立て替え金額")
                .font(.headline)
                .foregroundColor(Color.maincolor)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(payerData, id: \.user.id) { item in
                    let userKey = item.user.id == user1.id ? "user1" : "user2"
                    Button {
                        drillDownItem = DrillDownItem(
                            title: "\(item.user.name)の立て替え",
                            filter: .payer(userKey)
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(item.user.iconName == "poodle" ? Color.gray : Color.subcolor1)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if let uiImage = item.user.avatarImage {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                    } else if !item.user.iconName.isEmpty {
                                        Image(item.user.iconName)
                                            .resizable()
                                            .scaledToFit()
                                            .padding(2)
                                    }
                                }

                            Text(item.user.name)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(Color.maincolor)

                            Spacer()

                            HStack(spacing: 4) {
                                Text("¥\(item.amount.formatted(.number.grouping(.automatic)))")
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                    .foregroundColor(Color.maincolor)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.maincolor.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if item.user.id != payerData.last?.user.id {
                        Divider()
                            .overlay(Color.maincolor.opacity(0.15))
                            .padding(.leading, 60)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .background(Color.background)
        .cornerRadius(12)
    }

    // MARK: - 共有支出ナビカード

    private var sharedRecordsNavCard: some View {
        HStack {
            Button { showSharedList = true } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("過去の共用支出記録を確認　")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.maincolor)
                        Text(sharedRecords.isEmpty ? "記録なし" : "\(sharedRecords.count)件")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.maincolor.opacity(0.5))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.maincolor.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.maincolor.opacity(0.3), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    // MARK: - 空状態

    private var emptyView: some View {
        Text("データがありません")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
    }
}

#Preview {
    GraphView(
        showSettings: .constant(false),
        user1: RecordsMockData.user1,
        user2: RecordsMockData.user2,
        records: RecordsMockData.records,
        onRefresh: nil
    )
}
