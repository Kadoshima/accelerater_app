# 研究アプリケーションプラットフォーム

## 概要

本プロジェクトは、様々な身体動作解析研究に対応可能な汎用的なFlutterアプリケーションプラットフォームです。基盤となる共通機能を持つ`plane`ブランチから、各研究に特化したブランチを派生させることで、効率的な研究アプリケーション開発を実現します。

## プロジェクト構造

### ブランチ戦略

```
main (安定版)
  └── plane (汎用基盤)
       ├── research/gait-v01 (歩行解析研究)
       ├── research/balance-v01 (バランス研究)
       └── research/... (その他の研究)
```

- **main**: 本番環境用の安定版ブランチ
- **plane**: すべての研究の出発点となる汎用的な基盤アプリケーション
- **research/***: 各研究に特化した機能を実装するブランチ

## 主要機能

### 基盤機能（planeブランチ）
- **センサーデータ収集**: IMU、心拍、GPSなどの汎用インターフェース
- **データ処理**: リアルタイム/バッチ処理フレームワーク
- **ストレージ**: ローカルDB、ファイル、クラウド同期
- **UI/UX**: 再利用可能なコンポーネントライブラリ
- **実験管理**: プロトコル管理、被験者管理、データエクスポート

### アーキテクチャ
Clean Architectureに基づく4層構造を採用しています。詳細は[ARCHITECTURE.md](./ARCHITECTURE.md)を参照してください。

## セットアップ

### 必要な環境
- Flutter SDK: 3.0.0以上
- Dart SDK: 3.0.0以上
- Android Studio / Xcode
- Git

### インストール手順

```bash
# リポジトリのクローン
git clone https://github.com/Kadoshima/accelerater_app.git
cd accelerater_app

# planeブランチへの切り替え（基盤開発の場合）
git checkout plane

# 依存関係のインストール
flutter pub get

# 開発サーバーの起動
flutter run
```

### 新しい研究プロジェクトの開始

```bash
# planeブランチから新しい研究ブランチを作成
git checkout plane
git checkout -b research/your-study-name

# 研究固有の設定を追加
# docs/your-study-name/に研究仕様書を作成
```

## 開発ガイドライン

### コーディング規約
- [Effective Dart](https://dart.dev/guides/language/effective-dart)に準拠
- コードフォーマット: `dart format`
- 静的解析: `dart analyze`

### コミットメッセージ
```
<type>: <subject>

<body>
```

タイプ:
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメント更新
- `refactor`: リファクタリング
- `test`: テスト追加・修正
- `chore`: ビルド設定等

## ドキュメント

- [アーキテクチャガイド](./ARCHITECTURE.md)
- [デザインシステム](./DESIGN_SYSTEM.md)
- [開発TODO](./TODO.md)
- [研究別ドキュメント](./docs/)

## 現在進行中の研究

### 歩行解析研究 (v01)
加速度センサーを用いた歩行リズム解析と音響フィードバックによる歩行改善の研究。詳細は[docs/v01/](./docs/v01/)を参照。

## ライセンス

本プロジェクトは研究目的での使用を前提としています。商用利用については別途お問い合わせください。

## 貢献

1. Issueで機能提案・バグ報告
2. Pull Requestは`plane`ブランチへ
3. レビュー後にマージ

## 連絡先

- プロジェクトリード: [お名前]
- Email: [メールアドレス]
- 研究室: [所属]