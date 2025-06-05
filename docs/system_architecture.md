# 歩行解析・音響フィードバックシステム アーキテクチャ

## 更新履歴
- 2025/6/2: リファクタリングによるアーキテクチャ改善
- 2024/6/4: 反応研究機能、加速度データ完全記録、個別対応機能の追加

## システム概要

このFlutterアプリケーションは、リアルタイムで心拍数を監視しながら、マイコン（M5Stick）から加速度データを取得し、歩行パターンを分析して音響フィードバックを提供する研究用システムです。

## 主要コンポーネント

### 1. 心拍数モニタリングシステム

#### 概要
- BLE (Bluetooth Low Energy) 経由で心拍数データをリアルタイム受信
- 標準BLE心拍数サービスとHuawei独自プロトコルの両方をサポート
- 1秒ごとにUIを更新し、最新の心拍数を表示

#### 実装詳細
- **ファイル**: `lib/main.dart` (BLEHomePage)
- **標準BLEサービスUUID**: `0000180d-0000-1000-8000-00805f9b34fb`
- **心拍数測定特性UUID**: `00002a37-0000-1000-8000-00805f9b34fb`
- **データバッファリング**: 最新3-5個の値を保持してスムージング
- **重複除去**: 500msのしきい値で重複データを除外
- **有効範囲**: 30-220 BPM

#### プロトコル対応
1. **標準BLE形式**:
   - バイト0: フラグ
   - バイト1: 心拍数（8ビット）またはバイト1-2（16ビット）

2. **Huaweiカスタムプロトコル**:
   - ヘッダー: `0x5A 0x00`
   - バイト2-3: ペイロード長（リトルエンディアン）
   - バイト4: コマンド（0x09 = 心拍数）
   - バイト9: 心拍数値

### 2. 加速度データ収集システム

#### 概要
- M5Stickデバイスから3軸加速度データをBLE経由で受信
- JSON形式でデータを送受信
- リアルタイムで加速度の大きさ（magnitude）を計算

#### 実装詳細
- **IMUサービスUUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **IMU特性UUID**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- **デバイス名**: "M5StickIMU"
- **サンプリングレート**: 60Hz（固定）

#### データ構造 (`models/sensor_data.dart`)
```dart
M5SensorData {
  device: String      // デバイス識別子
  timestamp: int      // エポックからのミリ秒
  type: String        // "raw", "imu", "bpm"
  data: {
    accX: double      // X軸加速度
    accY: double      // Y軸加速度
    accZ: double      // Z軸加速度
    gyroX: double     // X軸ジャイロ
    gyroY: double     // Y軸ジャイロ
    gyroZ: double     // Z軸ジャイロ
    magnitude: double // 3軸合成加速度
  }
}
```

### 3. 歩行解析システム

#### 概要
- FFT（高速フーリエ変換）を使用した周波数解析
- 歩行ケイデンス（SPM: Steps Per Minute）の検出
- リアルタイムで歩数カウントとSPM計算

#### アルゴリズム詳細 (`utils/gait_analysis_service.dart`)
1. **FFTベース解析**:
   - ウィンドウサイズ: 10秒（設定可能）
   - スライディングウィンドウ: 1秒間隔
   - ハミング窓を適用してエッジ効果を軽減

2. **前処理**:
   - トレンド除去（平均値減算）
   - 静止状態検出（標準偏差しきい値）

3. **ピーク検出**:
   - 周波数範囲: 1.0-3.5 Hz (60-210 SPM)
   - SNR（信号対雑音比）計算による信頼性評価
   - 高調波・低調波の関係を考慮

4. **補正係数**:
   - 7%の削減係数を適用（系統的な過大評価を補正）

#### 出力メトリクス
- **現在のSPM**: FFTから計算された歩行ペース
- **歩数カウント**: 累積歩数
- **信頼性スコア**: 0-1の範囲（SNRベース）
- **安定性判定**: 一定期間の安定性

### 4. 音響フィードバックシステム

#### 概要
- 高精度メトロノームによる音響フィードバック
- ネイティブプラットフォーム実装（iOS/Android）
- リアルタイムテンポ調整

#### 実装アーキテクチャ
1. **Flutterメトロノーム** (`services/metronome.dart`):
   - プログラムによるクリック音生成（正弦波）
   - 44.1kHz、16ビットPCM
   - 1msタイマー精度

2. **ネイティブメトロノーム** (`services/native_metronome.dart`):
   - プラットフォームチャンネル経由
   - iOS: AVAudioEngine使用
   - Android: AudioTrack使用

#### iOS実装特徴
- **リアルタイムオーディオ**: AVAudioSourceNode（iOS 13+）
- **超低遅延**: 2msバッファ設定
- **サンプル精度タイミング**: 44.1kHz/48kHz
- **システム振動**: AudioServicesPlaySystemSound

#### Android実装特徴
- **AudioTrack**: 静的モード使用
- **高精度タイマー**: HandlerThreadで1ms精度
- **ドリフト防止**: 理論的次ビート計算

### 5. 実験制御システム

#### 概要 (`services/experiment_controller.dart`)
- 複数フェーズの実験プロトコル管理
- 歩行ペースに基づく適応的テンポ調整
- データ収録と分析

#### 実験フェーズ
1. **ベースライン**: 自然な歩行ペースを記録
2. **適応**: ベースラインSPMでメトロノーム導入
3. **誘導**: 段階的にテンポを増減（5 BPM刻み）

#### データ収録
- タイムシリーズデータ（2秒間隔）
- メタデータ（信頼性、歩数、安定性など）
- 実験条件とセッション情報

## 新アーキテクチャ

### レイヤードアーキテクチャ

```
Presentation層 (UI/状態管理)
│
├── Screens (画面)
├── Widgets (再利用可能なUIコンポーネント)
└── Providers (Riverpod状態管理)

Domain層 (ビジネスロジック)
│
├── Entities (ドメインモデル)
├── Repositories (インターフェース)
└── UseCases (ユースケース)

Data層 (データアクセス)
│
├── Repositories (実装)
├── DataSources (データソース)
└── Models (DTO)

Core層 (共通機能)
│
├── Constants (定数)
├── Errors (例外)
└── Utils (ユーティリティ)
```

### エラーハンドリング

Either型を使用した安全なエラー処理：

```dart
typedef Result<T> = Either<AppException, T>;

// 使用例
final result = await repository.connectDevice(deviceId);
result.fold(
  (error) => showError(error.message),
  (success) => showSuccess(),
);
```

## システム統合

### データフロー
1. **センサーデータ受信**:
   - BLE通知 → データパース → バリデーション

2. **リアルタイム処理**:
   - 加速度データ → FFT解析 → SPM計算
   - 心拍数データ → プロトコル解析 → 表示更新

3. **フィードバックループ**:
   - 検出SPM → 目標BPM比較 → メトロノーム調整

4. **データ記録**:
   - 全メトリクス → タイムスタンプ付加 → ファイル保存

### 同時実行管理
- 複数のBLEデバイス接続（心拍計 + IMU）
- 独立したデータストリーム処理
- タイマーベースの同期更新

## 技術的特徴

1. **マルチプロトコル対応**: 異なるBLEデバイスの自動検出
2. **リアルタイム性能**: 低遅延オーディオと高速データ処理
3. **堅牢性**: エラー処理とフォールバック機構
4. **研究グレード精度**: サンプル精度のタイミングと較正済みアルゴリズム
5. **クロスプラットフォーム**: iOS/Androidで一貫した動作

## 2024年6月の新機能

### 1. 反応研究対応システム

#### 概要
音への反応を定量的に測定するための実験モードを追加しました。

#### 実装詳細
- **ExperimentType列挙型**: traditional（従来型）、randomOrder（ランダム順序）
- **RandomPhaseType**: freeWalk（自由歩行）、pitchKeep（ピッチ維持）、pitchIncrease（ピッチ上昇）
- **反応時間計測**: ミリ秒単位での音刺激から歩行変化までの時間記録

#### ランダム化機能
```dart
ExperimentUtils.generateRandomPhaseSequence(
  phaseCount: 6,
  minPhaseDuration: Duration(minutes: 1),
  maxPhaseDuration: Duration(minutes: 3),
)
```

### 2. 加速度データ完全記録システム

#### 概要
1時間分の加速度センサーデータを完全に記録・保存する機能を実装しました。

#### 実装詳細
- **AccelerometerDataBuffer**: 最大360,000データポイントのリングバッファ
- **自動保存**: 実験終了時にCSVファイルとして出力
- **メモリ管理**: 約36MBのメモリ使用量で1時間分のデータを保持

#### データ構造
```dart
class AccelerometerDataBuffer {
  final int maxBufferSize = 360000; // 100Hz × 3600秒
  
  void add(M5SensorData data);
  List<M5SensorData> getDataInTimeRange(DateTime start, DateTime end);
  double get estimatedMemoryUsageMB;
}
```

### 3. 適応的テンポ制御システム

#### 概要
個人の反応特性に応じてメトロノームのテンポを自動調整する機能です。

#### 実装詳細 (`services/adaptive_tempo_controller.dart`)
1. **個人パラメータ**:
   - responsivenessScore: 音刺激への反応性（0.5-2.0）
   - stabilityPreference: 安定性重視度（0.5-2.0）
   - maxComfortableSpm: 最大快適歩行ペース

2. **リアルタイム調整**:
   - 微細な調整（±1%/秒）で無意識的な誘導
   - 安定性と反応性のバランスを考慮
   - 長時間安定時の増加率向上

3. **学習機能**:
   - セッションデータから個人特性を学習
   - パラメータの自動最適化
   - JSON形式でのパラメータ保存/読み込み

### 4. 歩行安定性分析

#### 変動係数（CV）計算
```dart
class GaitStabilityAnalyzer {
  static double calculateCV(List<double> strideIntervals) {
    // 平均と標準偏差から変動係数を計算
    return stdDev / mean;
  }
  
  static double calculateSymmetry(List<double> leftSteps, List<double> rightSteps) {
    // 左右の歩幅差から対称性を評価
    return 1.0 - asymmetryRatio;
  }
}
```

### 5. 拡張されたデータ構造

#### ExperimentSession の拡張
- `ExperimentType experimentType`: 実験タイプ
- `List<RandomPhaseInfo>? randomPhaseSequence`: ランダムフェーズ情報
- `double currentCV`: 現在の変動係数
- `Duration? responseTime`: 反応時間

#### CSVデータの拡張フィールド
- `cv`: 変動係数
- `responseTime`: 反応時間（ミリ秒）
- `useAdaptiveControl`: 適応制御の有効/無効
- `adaptiveTargetSpm`: 適応制御による目標SPM

## 使用ライブラリ
- `flutter_blue_plus`: BLE通信
- `just_audio`: オーディオ再生
- `sensors_plus`: デバイスセンサーアクセス
- `fftea`: 高速フーリエ変換
- `vibration`: 触覚フィードバック
- `flutter_riverpod`: 状態管理
- `go_router`: ルーティング
- `fpdart`: 関数型プログラミング
- `freezed`: イミュータブルモデル
- `logger`: 構造化ログ
- `csv`: CSVファイル処理
- `path_provider`: ファイルパス管理