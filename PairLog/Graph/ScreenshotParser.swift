import Vision
import UIKit
import Foundation

// MARK: - Model

struct ParsedTransaction {
    let amount: Int
    let memo: String
    let date: Date
}

// MARK: - Parser

struct ScreenshotParser {

    /// スクリーンショット画像からトランザクション一覧を抽出する（バックグラウンド実行）
    static func parse(image: UIImage) async -> [ParsedTransaction] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: parseSync(image: image))
            }
        }
    }

    // MARK: - Sync core

    private static func parseSync(image: UIImage) -> [ParsedTransaction] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = ["ja-JP", "en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else { return [] }

        let rows = groupIntoRows(observations)
        return extractTransactions(from: rows)
    }

    // MARK: - Row grouping

    /// 同じ行にあるテキストをまとめる（Y座標の近さで判定）
    private static func groupIntoRows(
        _ observations: [VNRecognizedTextObservation]
    ) -> [[(text: String, minX: CGFloat)]] {

        // Vision座標系: 左下が原点なので midY が大きいほど上にある
        let items = observations.compactMap { obs -> (text: String, box: CGRect)? in
            guard let top = obs.topCandidates(1).first, !top.string.trimmingCharacters(in: .whitespaces).isEmpty
            else { return nil }
            return (text: top.string, box: obs.boundingBox)
        }.sorted { $0.box.midY > $1.box.midY }

        // (text, minX, midY, height)
        typealias Item = (text: String, minX: CGFloat, midY: CGFloat, height: CGFloat)
        var rows: [[Item]] = []

        for item in items {
            var placed = false
            for i in rows.indices.reversed() {
                let rowMidY = rows[i].map(\.midY).reduce(0, +) / CGFloat(rows[i].count)
                let rowHeight = rows[i].map(\.height).max() ?? 0.02
                if abs(item.box.midY - rowMidY) < rowHeight * 0.9 {
                    rows[i].append((item.text, item.box.minX, item.box.midY, item.box.height))
                    placed = true
                    break
                }
            }
            if !placed {
                rows.append([(item.text, item.box.minX, item.box.midY, item.box.height)])
            }
        }

        // 各行を左→右の順に並べ替えて返す
        return rows.map { row in
            row.sorted { $0.minX < $1.minX }.map { (text: $0.text, minX: $0.minX) }
        }
    }

    // MARK: - Amount extraction

    /// ¥1,234 / 1,234円 / -¥1,234 / −1,234 などを検出
    private static let amountPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: "[¥￥]\\s*([0-9][0-9,]*)"),
        try! NSRegularExpression(pattern: "([0-9][0-9,]+)\\s*円"),
        try! NSRegularExpression(pattern: "[-−]\\s*([0-9][0-9,]+)"),
    ]

    private static func extractAmount(from text: String) -> Int? {
        for regex in amountPatterns {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               match.numberOfRanges > 1,
               let r = Range(match.range(at: 1), in: text) {
                let numStr = String(text[r]).replacingOccurrences(of: ",", with: "")
                if let amount = Int(numStr), amount >= 10, amount < 10_000_000 {
                    return amount
                }
            }
        }
        return nil
    }

    // MARK: - Date extraction

    private static func extractDate(from text: String) -> Date? {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())

        // YYYY/MM/DD、YYYY.MM.DD、YYYY-MM-DD
        if let m = match(text, pattern: "(\\d{4})[/\\.\\-](\\d{1,2})[/\\.\\-](\\d{1,2})"),
           let y = Int(m[1]), let mo = Int(m[2]), let d = Int(m[3]) {
            return cal.date(from: DateComponents(year: y, month: mo, day: d))
        }
        // M月D日 (曜日があっても可)
        if let m = match(text, pattern: "(\\d{1,2})月(\\d{1,2})日"),
           let mo = Int(m[1]), let d = Int(m[2]) {
            return cal.date(from: DateComponents(year: currentYear, month: mo, day: d))
        }
        // MM/DD または M/D（前後に数字がないことを確認）
        if let m = match(text, pattern: "(?<![\\d])(\\d{1,2})/(\\d{1,2})(?![\\d])"),
           let mo = Int(m[1]), let d = Int(m[2]),
           mo >= 1, mo <= 12, d >= 1, d <= 31 {
            return cal.date(from: DateComponents(year: currentYear, month: mo, day: d))
        }
        return nil
    }

    /// 正規表現マッチしてキャプチャグループ文字列の配列を返す（index 0 = 全体）
    private static func match(_ text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        return (0..<match.numberOfRanges).compactMap {
            Range(match.range(at: $0), in: text).map { String(text[$0]) }
        }
    }

    // MARK: - Transaction extraction

    private static func extractTransactions(
        from rows: [[(text: String, minX: CGFloat)]]
    ) -> [ParsedTransaction] {
        var results: [ParsedTransaction] = []

        for (rowIdx, row) in rows.enumerated() {
            let rowText = row.map(\.text).joined(separator: " ")
            guard let amount = extractAmount(from: rowText) else { continue }

            // ±2行の範囲で日付を探す
            var date: Date?
            let searchRange = max(0, rowIdx - 2)...min(rows.count - 1, rowIdx + 2)
            for idx in searchRange {
                let t = rows[idx].map(\.text).joined(separator: " ")
                if let d = extractDate(from: t) { date = d; break }
            }

            // メモ：同じ行から金額・日付以外のテキストを取得
            let memoTokens = row.map(\.text).filter { chunk in
                extractAmount(from: chunk) == nil &&
                extractDate(from: chunk) == nil &&
                !["¥", "￥", "円", "-", "−", "+"].contains(chunk.trimmingCharacters(in: .whitespaces))
            }
            var memo = memoTokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)

            // メモが空なら隣の行から取得（金額がない行を優先）
            if memo.isEmpty {
                for offset in [-1, 1, -2, 2] {
                    let idx = rowIdx + offset
                    guard (0..<rows.count).contains(idx) else { continue }
                    let adjText = rows[idx].map(\.text).joined(separator: " ")
                    if extractAmount(from: adjText) == nil {
                        memo = adjText.trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            }

            // 同一金額・同一日付は重複とみなしスキップ
            let finalDate = date ?? Date()
            let isDup = results.contains { r in
                r.amount == amount && abs(r.date.timeIntervalSince(finalDate)) < 86400
            }
            guard !isDup else { continue }

            results.append(ParsedTransaction(amount: amount, memo: memo, date: finalDate))
        }

        return results
    }
}
