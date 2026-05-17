import Foundation

struct CSVRecord {
    let date: Date
    let amount: Int
    let memo: String
    let category: String
}

/// CSV テキストをパースして CSVRecord 配列を返すパーサー
///
/// ヘッダー行の列名（日付・金額・内容・カテゴリ等）から列順を自動検出する。
/// ヘッダーがない場合は固定順（日付, 金額 [, 内容 [, カテゴリ]]）とみなす。
/// UTF-8 / Shift-JIS は呼び出し元で変換済みの文字列を受け取る。
enum CSVParser {

    static func parse(csvString: String) -> [CSVRecord] {
        var lines = csvString
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return [] }

        let firstCells = splitCSVLine(lines[0]).map { $0.trimmingCharacters(in: .whitespaces) }

        let columns: ColumnIndices
        if let detected = detectColumns(from: firstCells) {
            // ヘッダー行あり → 検出した列インデックスを使う
            columns = detected
            lines.removeFirst()
        } else if parseDate(firstCells.first ?? "") != nil {
            // ヘッダーなし・先頭が日付 → 固定順: 日付, 金額 [, 内容 [, カテゴリ]]
            columns = ColumnIndices(date: 0, amount: 1, memo: 2, category: 3)
        } else {
            // 不明なヘッダー → スキップして固定順にフォールバック
            lines.removeFirst()
            columns = ColumnIndices(date: 0, amount: 1, memo: 2, category: 3)
        }

        return lines.compactMap { parseLine($0, columns: columns) }
    }

    // MARK: - Column Detection

    private struct ColumnIndices {
        let date: Int
        let amount: Int
        let memo: Int?
        let category: Int?
    }

    private static func detectColumns(from headers: [String]) -> ColumnIndices? {
        let normalized = headers.map { $0.lowercased() }

        func find(_ keywords: [String]) -> Int? {
            for kw in keywords {
                if let idx = normalized.firstIndex(where: { $0.contains(kw) }) { return idx }
            }
            return nil
        }

        guard
            let dateIdx   = find(["日付", "date"]),
            let amountIdx = find(["金額", "amount", "利用金額", "支払金額"])
        else { return nil }

        return ColumnIndices(
            date:     dateIdx,
            amount:   amountIdx,
            memo:     find(["内容", "memo", "摘要", "品目", "店名", "利用先"]),
            category: find(["カテゴリ", "category"])
        )
    }

    // MARK: - Line Parsing

    private static func parseLine(_ line: String, columns: ColumnIndices) -> CSVRecord? {
        let cells = splitCSVLine(line).map { $0.trimmingCharacters(in: .whitespaces) }

        let maxRequired = max(columns.date, columns.amount)
        guard cells.count > maxRequired else { return nil }

        guard let date = parseDate(cells[columns.date]) else { return nil }

        let amountStr = cells[columns.amount]
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard let amount = Int(amountStr), amount > 0 else { return nil }

        let memo     = columns.memo.map     { $0 < cells.count ? cells[$0] : "" } ?? ""
        let category = columns.category.map { $0 < cells.count ? cells[$0] : "" } ?? ""

        return CSVRecord(date: date, amount: amount, memo: memo, category: category)
    }

    // MARK: - Helpers

    private static func parseDate(_ str: String) -> Date? {
        let formats = [
            "yyyy/MM/dd",
            "yyyy-MM-dd",
            "yyyyMMdd",
            "MM/dd/yyyy",
            "yyyy年MM月dd日",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: str) { return date }
        }
        return nil
    }

    /// ダブルクォート対応の CSV 1行パーサー
    private static func splitCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            switch char {
            case "\"":
                inQuotes.toggle()
            case "," where !inQuotes:
                result.append(current)
                current = ""
            default:
                current.append(char)
            }
        }
        result.append(current)
        return result
    }
}
