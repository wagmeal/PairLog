# PairLog

<p align="center">
  <img src="PairLog/Assets.xcassets/AppIcon.appiconset/image.png" width="120" alt="PairLog App Icon">
</p>

<p align="center">
  夫婦・カップルの立て替えを、かんたんに記録・精算できるiOSアプリ
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift" />
  <img src="https://img.shields.io/badge/SwiftUI-iOS%2016%2B-blue?logo=apple" />
  <img src="https://img.shields.io/badge/Firebase-Firestore%20%2F%20Auth-yellow?logo=firebase" />
  <img src="https://img.shields.io/badge/Platform-iOS-lightgrey?logo=apple" />
</p>

---

## 概要

PairLog は、夫婦・カップルの日々の立て替えを一緒に管理するためのiOSアプリです。

「誰がいくら払ったか」を記録するだけで精算金額を自動計算。グラフで支出の傾向を把握し、ふたりのお金の流れをシンプルに可視化します。Firebase によるリアルタイム同期で、どちらかが記録すれば即座にふたりに反映されます。

---

## 主な機能

### 📝 立て替え記録
- 金額・カテゴリ・日付・内容・支払者を記録
- ふたりの負担割合をスライダーで直感的に設定
- 記録後の精算プレビューをリアルタイム表示

### 💰 自動精算計算
- 記録をもとに「誰がいくら払えばトントンか」を自動計算
- 精算完了後は記録をアーカイブ（繰越または清算を選択可能）

### 📊 グラフで支出を可視化
- 月別・年別の支出グラフ
- カテゴリ別・ユーザー別の支出内訳
- 各項目をタップして該当レコードの一覧・編集へ遷移

### 🗂 カテゴリ管理
- カテゴリの追加・削除・並び替え
- 共用支出（立て替えなし）の専用記録・グラフ反映

### 👤 プロフィール設定
- ユーザー名・アバター画像を2人分設定
- 円形クロッパーで好きな範囲をアイコンに設定

### 🔐 認証
- メールアドレス＋パスワード
- Google サインイン
- Sign in with Apple

---

## 技術スタック

| カテゴリ | 内容 |
|---|---|
| 言語 | Swift 5.9 |
| UI | SwiftUI |
| アーキテクチャ | MV（ObservableObject） |
| バックエンド | Firebase Authentication / Cloud Firestore |
| 外部ライブラリ | Firebase iOS SDK, GoogleSignIn |
| 対応OS | iOS 16以上 |

---

## アーキテクチャ

機能別ディレクトリ構成を採用し、ViewModel が Firebase との読み書きを担当する MV パターンで実装しています。

```
PairLog/
├── Main/
│   ├── PairFundApp.swift       # エントリーポイント・セッション管理
│   ├── RootTabView.swift       # タブナビゲーション
│   ├── HomeViewModel.swift     # ホーム用データ取得
│   └── BrandColor.swift        # カラー・共通Viewモディファイア
├── Login/
│   ├── LoginView.swift
│   ├── RegisterView.swift
│   ├── AuthViewModel.swift     # Email / Google / Apple 認証
│   └── PairUsersSetupView.swift
├── Add/
│   ├── AddView.swift           # 立て替え記録追加・編集
│   └── AddViewModel.swift
├── Records/
│   ├── RecordsView.swift       # 立て替え一覧・精算
│   ├── RecordsViewModel.swift  # 精算計算ロジック
│   └── PastRecordsView.swift   # アーカイブ済み記録
├── Graph/
│   ├── GraphView.swift         # グラフ画面
│   ├── SharedExpenseAddView.swift
│   ├── SharedExpenseEditView.swift
│   └── RecordDrillDownView.swift  # カテゴリ・ユーザー別ドリルダウン
└── Settings/
    ├── SettingsView.swift
    └── CategoryManagementView.swift
```

---

## Firestore データ構造

```
users/{uid}/
├── pair_profile/main       # user1Name, user2Name
├── categories/{autoId}     # name, order, isDefault
└── records/{autoId}        # payerUserKey, amount, ratio, category, isArchived, isShared
```

---

## セットアップ

### 必要な環境
- Xcode 15以上
- iOS 16以上の実機またはシミュレーター
- Firebase プロジェクト（Authentication・Firestore を有効化）

### 手順

1. リポジトリをクローン
```bash
git clone https://github.com/wagmeal/PairLog.git
cd PairLog
```

2. Firebase コンソールで iOS アプリを登録し、`GoogleService-Info.plist` を取得

3. 取得した `GoogleService-Info.plist` を `PairLog/` ディレクトリに配置

4. Xcode でプロジェクトを開いてビルド
```
open PairLog.xcodeproj
```

> **Note**
> `GoogleService-Info.plist` はセキュリティのため `.gitignore` に含まれており、リポジトリには含まれていません。

---

## こだわりポイント

- **リアルタイム同期**：Firestore のリアルタイムリスナーを使い、片方が記録するともう一方に即時反映
- **精算ロジック**：支払金額・負担割合から「誰がいくら払えば0になるか」を正確に算出
- **UX**：キーボードの「完了」ボタン、Return キーでの閉じる挙動、ライトモード固定など細部の使い勝手を調整
- **グラフのドリルダウン**：カテゴリ・ユーザー別の集計から、該当レコードの一覧・編集まで一気に遷移できる導線

---

## ライセンス

MIT License

---

## 作者

**Takumi Kowatari**
