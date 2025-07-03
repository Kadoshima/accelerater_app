# 可変難度・二重課題プロトコル 実装TODOリスト

## Phase 0: 高優先度コンポーネント実装（Week 1）

### 0.1 AdaptiveTempoService実装（★★★）✅
- [x] 最小二乗線形予測アルゴリズムの実装
  - [x] 将来位相推定ロジック
  - [x] リアルタイム位相補正機能
- [x] ゲインパラメータの実装
  - [x] kϕ = 0.35（位相ゲイン）
  - [x] kT = 0.10（周期ゲイン）
- [x] BPM更新式の実装: BPM_t+1 = BPM_t + kϕ·e_t + kT·(e_t - e_t-1)
- [ ] 単体テストとパフォーマンステスト
- 実装ファイル: `/lib/services/adaptive_tempo_service.dart`

### 0.2 PhaseErrorEngine実装（★★★）✅
- [x] リアルタイム位相誤差計算
  - [x] e_t = click_t - heelstrike_t の継続的計算
  - [x] RMSE_φ = √(Σ(e_t)²/n) の実装
- [x] 収束時間自動検出
  - [x] T_c計算（|SPM-target|<3 SPM までの時間）
  - [x] 収束状態の判定ロジック
- [x] データストリーミングとバッファリング
- 実装ファイル: `/lib/services/phase_error_engine.dart`

### 0.3 AudioConflictResolver実装（★★☆）✅
- [x] メトロノームclick時刻の予測
- [x] n-back音声再生時刻の管理
- [x] 衝突検出アルゴリズム（<200ms判定）
- [x] 自動シフト機能（±100ms調整）
- [x] 衝突ログの記録
- 実装ファイル: `/lib/services/audio_conflict_resolver.dart`

### 0.4 拡張CSV出力（★★☆）✅
- [x] deltaC計算ロジック（CV_fixed - CV_baseline）
- [x] deltaR計算ロジック（CV_fixed - CV_adaptive）
- [x] RMSE_phi、Tc のCSVカラム追加
- [x] phase_correction_gain、tempo_adjustmentカラム追加
- 実装ファイル: `/lib/services/extended_data_recorder.dart`

## Phase 1: 基盤システム準備（Week 1）

### 1.1 プロジェクト設定 ✅
- [x] 新しいブランチ作成: `feature/dual-task-protocol`
- [x] 必要な依存関係の追加
  - [x] flutter_tts (Text-to-Speech)
  - [x] speech_to_text (音声認識)
  - [x] audioplayers (音声再生制御)
- [x] pubspec.yamlの更新とpackage取得

### 1.2 データモデル設計 ✅
- [x] N-back課題用のデータモデル作成
  ```dart
  class NBackTask {
    final int nLevel; // 0, 1, 2
    final List<int> sequence;
    final List<NBackResponse> responses;
  }
  ```
- [x] 実験セッションモデルの拡張
  - [x] 認知負荷レベルフィールド追加
  - [x] N-back成績記録フィールド追加
- 実装ファイル: `/lib/models/nback_models.dart`

### 1.3 データベーススキーマ更新
- [ ] 既存のCSV出力形式を拡張
  - [ ] N-back正答率カラム追加
  - [ ] 反応時間カラム追加
  - [ ] 認知負荷レベルカラム追加

## Phase 2: N-backモジュール実装（Week 1-2）

### 2.1 N-back課題ジェネレーター ✅
- [x] ランダム数字列生成クラス実装
  ```dart
  class NBackSequenceGenerator {
    List<int> generate(int length, {int minDigit = 1, int maxDigit = 9});
  }
  ```
- [x] 正答判定ロジック実装
- [ ] 単体テスト作成
- 実装ファイル: `/lib/services/nback_sequence_generator.dart`

### 2.2 音声合成システム ✅
- [x] TTSラッパークラス実装
  - [x] 言語設定（日本語/英語）
  - [x] 速度調整機能
  - [x] 音量調整機能
- [x] 数字読み上げメソッド実装
- [x] タイミング制御（2秒間隔）
- 実装ファイル: `/lib/services/tts_service.dart`

### 2.3 応答収集システム ✅
- [x] 音声認識の実装（オプション）
  - [x] マイク権限取得
  - [x] 数字認識の最適化
- [x] ボタン入力UI実装（フォールバック）
  - [x] 数字ボタングリッド（1-9）
  - [x] 応答タイムアウト処理
- 実装ファイル: `/lib/services/nback_response_collector.dart`

### 2.4 N-back UIコンポーネント ✅
- [x] N-back表示ウィジェット作成
  - [x] 現在の数字表示
  - [x] 応答フィードバック（正解/不正解）
  - [x] 進行状況インジケーター
- [x] 設定画面への統合
- 実装ファイル: 
  - `/lib/presentation/widgets/nback_display_widget.dart`
  - `/lib/presentation/screens/nback_settings_screen.dart`

## Phase 3: 実験制御システム統合（Week 2）

### 3.1 実験モード拡張 ✅
- [x] 既存の実験モードに認知負荷条件を追加
- [x] 6条件の管理システム実装
  ```dart
  enum CognitiveLoad { none, nBack0, nBack1, nBack2 }
  enum TempoControl { adaptive, fixed }
  ```
- 実装ファイル: `/lib/services/experiment_condition_manager.dart`

### 3.2 実験フロー制御 ✅
- [x] ラテン方格デザイン順序生成器
- [x] 条件切り替えロジック
- [x] 実験ブロック管理（6分構成）
  - [x] Baseline自由歩行（60s）
  - [x] 同期フェーズ（120s）
  - [x] Challengeフェーズ（60s×2）
  - [x] 安定観察期間（30s）
- [x] 休憩タイマー実装
- [x] 進行状況トラッカー
- 実装ファイル: `/lib/services/experiment_flow_controller.dart`

### 3.3 データ同期システム ✅
- [x] タイムスタンプ同期メカニズム
  - [x] IMUデータ（100Hz）
  - [x] 心拍データ（3s間隔更新）
  - [x] N-back応答データ
- [x] バッファリングとフラッシュ処理
- [x] Polar H10の3秒更新仕様への対応
- 実装ファイル: `/lib/services/data_synchronization_service.dart`

## Phase 4: UI/UX改善（Week 2-3）✅

### 4.1 実験者用インターフェース ✅
- [x] 実験制御ダッシュボード
  - [x] 現在の条件表示
  - [x] 被験者パフォーマンス表示
  - [x] 緊急停止ボタン
- [x] リアルタイムモニタリング画面
- 実装ファイル: `/lib/presentation/screens/experiment_control_dashboard.dart`

### 4.2 被験者用インターフェース ✅
- [x] 指示画面の作成
  - [x] 各条件の説明
  - [x] 練習モード（デモ表示）
- [x] リアルタイムパフォーマンス表示
  - [x] n-back正答率（1分ローリング平均）
  - [x] 正答率逸脱警告（<70% or >90%）
- [x] NASA-TLX入力画面
- [x] 休憩中の表示
- 実装ファイル: 
  - `/lib/presentation/screens/participant_instruction_screen.dart`
  - `/lib/presentation/screens/nasa_tlx_screen.dart`
  - `/lib/presentation/screens/rest_screen.dart`

### 4.3 音声ガイダンス ✅
- [x] 実験開始/終了アナウンス
- [x] 条件切り替えアナウンス
- [x] エラー時の音声フィードバック
- [x] カウントダウン機能
- [x] AudioConflictResolverとの統合
- 実装ファイル: `/lib/services/voice_guidance_service.dart`

## Phase 5: テストと検証（Week 3）✅

### 5.1 ユニットテスト ✅
- [x] N-back課題ロジックのテスト
  - [x] シーケンス生成の正確性
  - [x] 応答検証ロジック
  - [x] 統計計算機能
- [x] データ同期のテスト
  - [x] 異なるサンプリングレートの同期
  - [x] バッファリングとフラッシュ
  - [x] タイムスタンプ補正
- [x] 順序生成器のテスト
  - [x] ラテン方格デザインの検証
  - [x] カウンターバランシング確認
- 実装ファイル:
  - `/test/services/nback_sequence_generator_test.dart`
  - `/test/services/data_synchronization_service_test.dart`
  - `/test/services/experiment_condition_manager_test.dart`

### 5.2 統合テスト ✅
- [x] 6条件全ての動作確認
  - [x] 適応/固定テンポ制御の切り替え
  - [x] 0/1/2-back課題の実行
- [x] データ記録の完全性確認
  - [x] 全データタイプの記録
  - [x] エクスポート形式の検証
- [x] タイミング精度の検証
  - [x] メトロノームBPM精度（±5ms）
  - [x] N-back刺激提示間隔（±10ms）
  - [x] フェーズ遷移タイミング
  - [x] 高頻度サンプリング（100Hz）の安定性
- 実装ファイル:
  - `/test/integration/dual_task_protocol_integration_test.dart`
  - `/test/services/timing_accuracy_test.dart`

### 5.3 パイロットテスト準備
- [ ] テスト用被験者6名の募集
- [ ] 同意書の準備
- [ ] テスト環境のセットアップ

## Phase 6: データ解析準備（Week 3）

### 6.1 解析スクリプト作成
- [ ] Pythonによるデータ前処理スクリプト
  - [ ] CSV読み込み
  - [ ] 欠損値処理
  - [ ] 変数計算（CV、エントロピー等）
  - [ ] deltaC、deltaR計算
  - [ ] RMSE_phi、Tc計算
- [ ] R用の統計解析スクリプト
  - [ ] 混合効果モデル
  - [ ] 位相・収束解析
  - [ ] 可視化

### 6.2 レポート生成
- [ ] 自動レポート生成システム
  - [ ] 個人別サマリー
  - [ ] 条件別比較グラフ
- [ ] PDFエクスポート機能

## Phase 7: ドキュメント作成

### 7.1 技術ドキュメント
- [ ] APIドキュメント更新
- [ ] データフォーマット仕様書
- [ ] トラブルシューティングガイド

### 7.2 実験ドキュメント
- [ ] 実験者用マニュアル
- [ ] 被験者用説明書
- [ ] データ管理プロトコル

## リスク管理

### 技術的リスク
- [ ] 音声認識精度の問題 → ボタン入力で代替
- [ ] タイミング同期の問題 → NTPによる時刻同期
- [ ] メモリ使用量の増大 → 定期的なデータフラッシュ
- [ ] 音声とメトロノームの衝突 → AudioConflictResolverで自動調整

### 実験的リスク
- [ ] 被験者の疲労 → 適切な休憩時間の設定
  - [ ] 歩行速度モニタリング（<0.9×baseline警告）
  - [ ] 自動休憩促しシステム
- [ ] 練習効果 → カウンターバランス設計
- [ ] ドロップアウト → 予備被験者の確保
- [ ] 正答率の逸脱 → リアルタイムHUD表示で監視

## 成功指標

- [ ] 全6条件で安定したデータ収集（エラー率<1%）
- [ ] N-back課題の応答率>90%
- [ ] データ同期精度<50ms
- [ ] パイロット被験者からの良好なフィードバック