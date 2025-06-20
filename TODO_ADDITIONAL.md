# 汎用アプリ化のための追加TODO

## 現在のTODO.mdでカバーされていない重要項目

### 1. 既存コードのリファクタリング
- [ ] 歩行解析特化のコードを分離
  - [ ] gait_analysis_*.dartをプラグイン化
  - [ ] experiment_controller.dartを汎用化
  - [ ] adaptive_tempo_controller.dartを歩行研究プラグインへ
- [ ] センサー関連の抽象化
  - [ ] ble_service.dartから汎用インターフェース抽出
  - [ ] sensor_data.dartを基底クラス化

### 2. プラグインアーキテクチャの実装
- [ ] プラグインインターフェース定義
  ```dart
  abstract class ResearchPlugin {
    String get id;
    String get name;
    List<SensorType> get requiredSensors;
    Widget buildConfigScreen();
    DataProcessor createProcessor();
  }
  ```
- [ ] プラグインローダーの実装
- [ ] プラグイン登録システム

### 3. 設定管理システム
- [ ] 研究別設定スキーマ（JSON Schema）
- [ ] 設定ファイルローダー
- [ ] 実行時設定切り替え機能
- [ ] デフォルト設定とオーバーライド

### 4. データ処理パイプライン
- [ ] StreamControllerベースのパイプライン
- [ ] 処理ステージの定義
  ```dart
  abstract class ProcessingStage<T, R> {
    Stream<R> process(Stream<T> input);
  }
  ```
- [ ] フィルタチェーンの実装
- [ ] バックプレッシャー対応

### 5. 実験プロトコルDSL
- [ ] YAMLベースのプロトコル定義
  ```yaml
  protocol:
    name: "Generic Movement Study"
    phases:
      - type: baseline
        duration: 300s
        sensors: [imu, heart_rate]
      - type: intervention
        duration: 600s
        feedback: audio
  ```
- [ ] プロトコルパーサー
- [ ] 実行エンジン

### 6. センサーシミュレーター
- [ ] テスト用の仮想センサー実装
- [ ] 記録済みデータの再生機能
- [ ] ノイズ生成機能
- [ ] 異常値シミュレーション

### 7. 国際化（i18n）
- [ ] 言語ファイル構造の設計
- [ ] 動的言語切り替え
- [ ] 研究別の専門用語辞書

### 8. エラーハンドリングの統一
- [ ] エラー分類体系
- [ ] リカバリー戦略
- [ ] ユーザー向けエラーメッセージ
- [ ] 開発者向けログ

### 9. パフォーマンスモニタリング
- [ ] メトリクス収集
- [ ] リソース使用量追跡
- [ ] ボトルネック検出
- [ ] 最適化提案

### 10. セキュリティ強化
- [ ] データ暗号化レイヤー
- [ ] 認証・認可システム
- [ ] 監査ログ
- [ ] セキュアストレージ

## 実装優先順位

### Phase 0（前準備）- 1週間
1. 既存コードのリファクタリング
2. 歩行解析機能の分離

### Phase 1（基盤）- 2週間  
1. プラグインアーキテクチャ
2. センサー抽象化の完成
3. データ処理パイプライン

### Phase 2（拡張）- 2週間
1. 実験プロトコルDSL
2. 設定管理システム
3. センサーシミュレーター

### Phase 3（品質）- 1週間
1. エラーハンドリング統一
2. パフォーマンスモニタリング
3. 国際化

### Phase 4（セキュリティ）- 1週間
1. セキュリティ強化
2. 監査機能

## 注意事項

- 各フェーズは並列実行可能な部分あり
- 既存の歩行解析機能を壊さないよう段階的に移行
- テストカバレッジを維持しながら実装
- ドキュメントを同時に更新

これらを実装することで、真に汎用的な研究プラットフォームが完成します。