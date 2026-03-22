# PairLog - Claude Code ガイド

## プロジェクト概要
夫婦で建て替えを共同管理するiOSアプリ。
Firebase上にデータを保存し、同じアカウントで夫婦が記録・閲覧できる。

## 技術スタック
- **言語**: Swift
- **UI**: SwiftUI
- **アーキテクチャ**: MV（SwiftUIデフォルト）
- **ターゲット**: iOS 16以上
- **プロジェクトファイル**: PairLog.xcodeproj
- **バックエンド**: Firebase（Authentication + Firestore）

## ビルド・実行コマンド
ビルドやテストは必ずMCPツールを使うこと。生の `xcodebuild` コマンドは使わない。

- ビルド: `mcp__xcodebuildmcp__build_sim_name_proj`
- ビルド＋起動: `mcp__xcodebuildmcp__build_run_sim_name_proj`
- テスト: `mcp__xcodebuildmcp__test_sim_name_proj`
- シミュレーター一覧: `mcp__xcodebuildmcp__list_simulators`

デフォルトシミュレーター: iPhone 16（iOS 18）

## ディレクトリ構成
機能別ディレクトリ構成を採用している。

```
PairLog/
├── Main/
│   ├── PairFundApp.swift          # エントリーポイント（Firebase初期化、セッション管理）
│   ├── RootTabView.swift          # タブナビゲーション
│   ├── User.swift                 # ユーザーモデル
│   ├── BrandColor.swift           # カラー定義
│   └── RecordsMockData.swift      # プレビュー用モックデータ
├── Login/
│   ├── LoginView.swift            # ログイン画面
│   ├── RegisterView.swift         # 新規登録画面
│   ├── AuthViewModel.swift        # Firebase認証ロジック（Email/Google/Apple）
│   ├── PairUsersSetupView.swift   # パートナー設定（円形画像クロッパー含む）
│   └── UserProfile.swift          # ユーザープロフィールモデル
├── Add/
│   ├── AddView.swift              # 記録追加UI
│   └── AddViewModel.swift         # 記録追加ロジック（Firestore書き込み）
├── Records/
│   ├── RecordsView.swift          # 記録一覧画面
│   ├── RecordsViewModel.swift     # 精算計算ロジック
│   ├── RecordItem.swift           # 記録モデル
│   └── PastRecordsView.swift      # アーカイブ済み記録画面
├── Graph/
│   └── GraphView.swift            # グラフ画面（未実装）
├── Settings/
│   ├── SettingsView.swift         # 設定画面
│   └── CategoryManagementView.swift # カテゴリ管理
├── Assets.xcassets/               # 画像・アイコン素材
└── GoogleService-Info.plist       # Firebase設定（Gitに含めない）
```

## Firestore データ構造
```
users/{uid}/
├── pair_profile/main     # user1Name, user2Name
├── categories/{autoId}   # カテゴリ一覧（name, order, isDefault）
└── records/{autoId}      # 支出記録（payerUserKey, amount, ratio等）
```

## コーディングルール
- SwiftUI のベストプラクティスに従う
- 1ファイル1コンポーネントを原則とする
- 機能別ディレクトリに配置する（上記構成を維持する）
- Firebase の読み書きは ViewModel 内で行う
- エラーハンドリングは必ず実装する（`do-catch` または `Result` 型）
- 日本語コメントOK

## Firebase ルール
- 認証: Firebase Authentication（メール＋パスワード）
- DB: Firestore（リアルタイム同期を活用する）
- **`.pbxproj` ファイルは絶対に直接編集しない**
- `GoogleService-Info.plist` はGitにコミットしない

## 注意事項
- ファイルを新規作成した場合は必ずXcodeプロジェクトに追加する
- ビルドエラーが出たら自分で修正を試みてから報告する
- DerivedDataを不用意に削除しない
