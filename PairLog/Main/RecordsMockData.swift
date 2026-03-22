import SwiftUI

enum RecordsMockData {

    static let user1 = User(id: "takumi", name: "Takumi", iconName: "monster_green", tint: .mint)

    static let user2 = User(id: "partner", name: "Partner", iconName: "monster_gray", tint: .gray)

    // Preview用カテゴリ
    static let categories: [String] = [
        "未分類",
        "日用品",
        "交通費",
        "レジャー",
        "食費",
        "ペット",
        "カフェ",
        "娯楽"
    ]

    static let records: [RecordItem] = [

        // 2026年3月（今月）
        .init(payerUserKey: "user2", amount: 4820, title: "インターペット",
              user1Ratio: 50, user2Ratio: 50, category: "ペット",
              date: date(2026, 3, 17)),
        .init(payerUserKey: "user1", amount: 1200, title: "カフェ",
              user1Ratio: 50, user2Ratio: 50, category: "食費",
              date: date(2026, 3, 15)),
        .init(payerUserKey: "user2", amount: 3400, title: "スーパー",
              user1Ratio: 60, user2Ratio: 40, category: "食費",
              date: date(2026, 3, 10)),
        .init(payerUserKey: "user1", amount: 2800, title: "日用品まとめ買い",
              user1Ratio: 50, user2Ratio: 50, category: "日用品",
              date: date(2026, 3, 5)),

        // 2026年2月
        .init(payerUserKey: "user1", amount: 800, title: "駐車場",
              user1Ratio: 50, user2Ratio: 50, category: "交通費",
              date: date(2026, 2, 25)),
        .init(payerUserKey: "user2", amount: 5200, title: "ドッグラン",
              user1Ratio: 50, user2Ratio: 50, category: "ペット",
              date: date(2026, 2, 20)),
        .init(payerUserKey: "user1", amount: 1800, title: "ランチ",
              user1Ratio: 70, user2Ratio: 30, category: "食費",
              date: date(2026, 2, 14)),
        .init(payerUserKey: "user2", amount: 3600, title: "電球・消耗品",
              user1Ratio: 50, user2Ratio: 50, category: "日用品",
              date: date(2026, 2, 8)),

        // 2026年1月
        .init(payerUserKey: "user1", amount: 2600, title: "ディナー",
              user1Ratio: 50, user2Ratio: 50, category: "食費",
              date: date(2026, 1, 28)),
        .init(payerUserKey: "user2", amount: 4100, title: "レジャー施設",
              user1Ratio: 50, user2Ratio: 50, category: "レジャー",
              date: date(2026, 1, 20)),
        .init(payerUserKey: "user1", amount: 3200, title: "ガソリン",
              user1Ratio: 60, user2Ratio: 40, category: "交通費",
              date: date(2026, 1, 12)),
        .init(payerUserKey: "user2", amount: 900, title: "コーヒー豆",
              user1Ratio: 50, user2Ratio: 50, category: "食費",
              date: date(2026, 1, 5)),

        // 2025年12月
        .init(payerUserKey: "user1", amount: 8500, title: "クリスマスディナー",
              user1Ratio: 50, user2Ratio: 50, category: "食費",
              date: date(2025, 12, 24)),
        .init(payerUserKey: "user2", amount: 6200, title: "年末旅行",
              user1Ratio: 50, user2Ratio: 50, category: "レジャー",
              date: date(2025, 12, 28)),
        .init(payerUserKey: "user1", amount: 2100, title: "大掃除用品",
              user1Ratio: 50, user2Ratio: 50, category: "日用品",
              date: date(2025, 12, 15)),

        // 2025年11月
        .init(payerUserKey: "user2", amount: 3800, title: "ペットシャンプー",
              user1Ratio: 50, user2Ratio: 50, category: "ペット",
              date: date(2025, 11, 18)),
        .init(payerUserKey: "user1", amount: 1500, title: "映画",
              user1Ratio: 50, user2Ratio: 50, category: "レジャー",
              date: date(2025, 11, 10)),
        .init(payerUserKey: "user2", amount: 2400, title: "食料品",
              user1Ratio: 60, user2Ratio: 40, category: "食費",
              date: date(2025, 11, 3)),

        // 共用支出（isShared: true）
        .init(firestoreDocumentID: "shared-1",
              payerUserKey: "shared", amount: 12800, title: "電気代",
              user1Ratio: 50, user2Ratio: 50, category: "日用品",
              date: date(2026, 3, 1), isShared: true),
        .init(firestoreDocumentID: "shared-2",
              payerUserKey: "shared", amount: 8400, title: "ガス代",
              user1Ratio: 50, user2Ratio: 50, category: "日用品",
              date: date(2026, 3, 1), isShared: true),
        .init(firestoreDocumentID: "shared-3",
              payerUserKey: "shared", amount: 6200, title: "Netflix",
              user1Ratio: 50, user2Ratio: 50, category: "娯楽",
              date: date(2026, 2, 27), isShared: true),
        .init(firestoreDocumentID: "shared-4",
              payerUserKey: "shared", amount: 15600, title: "水道代",
              user1Ratio: 50, user2Ratio: 50, category: "日用品",
              date: date(2026, 2, 10), isShared: true),
        .init(firestoreDocumentID: "shared-5",
              payerUserKey: "shared", amount: 3200, title: "Spotify",
              user1Ratio: 50, user2Ratio: 50, category: "娯楽",
              date: date(2026, 1, 27), isShared: true),
        .init(firestoreDocumentID: "shared-6",
              payerUserKey: "shared", amount: 11200, title: "電気代",
              user1Ratio: 50, user2Ratio: 50, category: "日用品",
              date: date(2026, 1, 3), isShared: true),
    ]

    /// isShared == true のレコードのみ
    static let sharedRecords: [RecordItem] = records.filter { $0.isShared }

    // 日付生成ヘルパー
    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return Calendar.current.date(from: c) ?? Date()
    }
}
