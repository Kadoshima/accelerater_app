# 汎用研究プラットフォームへの移行計画

## 概要
このドキュメントは、現在の歩行解析専用アプリから汎用研究プラットフォームへの移行計画を記載しています。

## 移行戦略

### Phase 0: 基盤準備（現在実施中）
- [x] planeブランチの作成
- [x] プラグインアーキテクチャの基盤作成
  - [x] ResearchPluginインターフェース
  - [x] PluginLoader
  - [x] センサー抽象化インターフェース
- [x] 歩行解析プラグインの骨組み作成

### Phase 1: 歩行解析機能の分離（進行中）
以下のファイルをプラグインに移動：

#### サービス層
- [x] `/lib/services/adaptive_tempo_controller.dart` → `/lib/plugins/gait_analysis/services/`
- [x] `/lib/services/metronome.dart` → `/lib/plugins/gait_analysis/services/`
- [x] `/lib/utils/gait_analysis_service.dart` → `/lib/plugins/gait_analysis/services/`
- [x] `/lib/utils/spm_analysis.dart` → `/lib/plugins/gait_analysis/utils/`
- [x] `gait_analysis_plugin.dart` を作成

#### ドメイン層
- [ ] `/lib/domain/repositories/gait_analysis_repository.dart` → `/lib/plugins/gait_analysis/domain/`
- [ ] `/lib/data/repositories/gait_analysis_repository_impl.dart` → `/lib/plugins/gait_analysis/data/`

#### プレゼンテーション層
- [ ] `/lib/presentation/providers/gait_analysis_providers.dart` → `/lib/plugins/gait_analysis/presentation/`

#### 実験関連
- [ ] `/lib/services/experiment_controller.dart` → 汎用化して`/lib/core/experiment/`へ
- [ ] `/lib/screens/experiment_screen.dart` → `/lib/plugins/gait_analysis/presentation/screens/`

### Phase 2: 汎用化（進行中）
#### プラグインシステム
- [x] プラグインマネージャーの実装
- [x] プラグインプロバイダーの作成
- [x] プラグイン選択画面の実装
- [x] メインアプリへの統合（プラグイン選択ボタン追加）

#### センサー抽象化
- [x] センサー抽象化インターフェースの実装
- [x] センサーマネージャーの実装
- [ ] BLEサービスを汎用センサーインターフェースに適合
- [ ] M5SensorDataを汎用SensorDataに変換

#### 実験管理
- [ ] 汎用実験プロトコルエンジン
- [ ] プロトコルDSLパーサー
- [ ] 実験セッション管理の抽象化

#### データ処理
- [x] センサーデータレコーダーの実装（高性能バッファリング付き）
- [ ] ストリーム処理パイプライン
- [ ] フィルターチェーン
- [ ] データエクスポートの汎用化

### Phase 3: 新機能追加
- [ ] プラグイン設定UI
- [x] プラグイン選択画面
- [ ] センサーシミュレーター
- [ ] 開発者モード
- [ ] プラグインマーケットプレイス機能

## ファイル構造（移行後）

```
lib/
├── core/                      # 汎用基盤
│   ├── plugins/              # プラグインシステム
│   ├── sensors/              # センサー抽象化
│   ├── experiment/           # 実験管理
│   ├── data_processing/      # データ処理
│   └── export/               # データエクスポート
├── plugins/                   # 研究別プラグイン
│   └── gait_analysis/        # 歩行解析プラグイン
│       ├── domain/
│       ├── data/
│       ├── presentation/
│       └── services/
├── presentation/              # 汎用UI
│   ├── screens/              # 基本画面
│   ├── widgets/              # 共通ウィジェット
│   └── providers/            # 汎用プロバイダー
└── main.dart                  # エントリーポイント
```

## 注意事項

1. **後方互換性**: 移行中も既存の歩行解析機能は動作するよう維持
2. **段階的移行**: 一度にすべてを移行せず、段階的に実施
3. **テスト**: 各移行ステップでテストを実施
4. **ドキュメント**: 移行に合わせてドキュメントも更新

## 次のアクション

1. `adaptive_tempo_controller.dart`をプラグインに移動
2. センサーデータの抽象化実装
3. 基本的なプラグイン選択UIの作成