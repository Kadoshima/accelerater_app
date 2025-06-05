# 技術詳細ドキュメント

## 更新日: 2025/06/04

## アーキテクチャ概要

本システムはClean Architectureに基づいた以下のレイヤー構造を採用しています：

```
Presentation層 (UI/状態管理)
├── screens/              # 画面コンポーネント
├── widgets/              # 再利用可能なUIパーツ
└── providers/            # Riverpod状態管理

Domain層 (ビジネスロジック)
├── entities/             # ドメインモデル
├── repositories/         # リポジトリインターフェース
└── usecases/             # ユースケース

Data層 (データアクセス)
├── repositories/         # リポジトリ実装
├── datasources/          # データソース
└── models/               # データ転送オブジェクト

Core層 (共通機能)
├── constants/            # 定数定義
├── errors/               # 例外クラス
└── utils/                # ユーティリティ
```

## 1. BLE通信プロトコル

### 心拍数データ受信

#### 標準BLE心拍数サービス
```dart
// core/constants/ble_constants.dart
class BleConstants {
  static const heartRateServiceUuid = "0000180d-0000-1000-8000-00805f9b34fb";
  static const heartRateMeasurementUuid = "00002a37-0000-1000-8000-00805f9b34fb";
}

// データフォーマット（標準BLE）
// バイト0: フラグ（ビット0 = 心拍数フォーマット）
// - 0: 8ビット値（バイト1）
// - 1: 16ビット値（バイト1-2）
// 残りのバイト: オプション（エネルギー消費、RR間隔など）
```

#### Huaweiカスタムプロトコル
```dart
// data/repositories/bluetooth_repository_impl.dart内で処理
// プロトコル判定
if (data.length >= 2 && data[0] == 0x5a && data[1] == 0x00) {
  // Huaweiプロトコル
  // ヘッダー: 0x5A 0x00
  // バイト2-3: ペイロード長（リトルエンディアン）
  // バイト4: コマンド (0x09 = 心拍数)
  // バイト5: サブコマンド
  // バイト9: 心拍数値
  
  if (data.length >= 10 && data[4] == 0x09) {
    heartRate = data[9];
  }
}
```

### IMUデータ受信

#### M5Stick IMUプロトコル
```dart
// core/constants/ble_constants.dart
class BleConstants {
  static const imuServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const imuCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
}

// models/sensor_data.dart - M5SensorDataモデル
{
  "device": "M5StickIMU",
  "timestamp": 1234567890,
  "type": "imu",
  "data": {
    "accX": 0.123,
    "accY": -0.456,
    "accZ": 0.789,
    "gyroX": 1.23,
    "gyroY": -4.56,
    "gyroZ": 7.89,
    "magnitude": 0.987  // sqrt(accX² + accY² + accZ²)
  }
}
```

## 2. 歩行解析アルゴリズム

### FFTベース周波数解析

#### アルゴリズムパラメータ
```dart
// utils/gait_analysis_service.dart
class GaitAnalysisService {
  // 基本パラメータ
  final double samplingRate = 60.0;        // Hz
  final int windowSizeSeconds = 10;        // 解析ウィンドウ
  final int slideIntervalSeconds = 1;      // スライド間隔
  final double minFrequency = 1.0;         // Hz (60 SPM)
  final double maxFrequency = 3.5;         // Hz (210 SPM)
  
  // 品質パラメータ
  final double minStdDev = 0.05;           // 静止判定しきい値
  final double minSNR = 2.0;               // 最小信号対雑音比
  final double smoothingFactor = 0.3;      // 指数平滑化係数
}
```

#### FFT処理フロー
```dart
// utils/gait_analysis_service.dart: _processFFT()メソッド
1. データ前処理
   - 平均値除去（トレンド除去）
   - ハミング窓適用
   
2. FFT実行
   - Real FFT使用（実数データ用）
   - パワースペクトル計算
   
3. ピーク検出
   - 局所最大値検索
   - SNR計算
   - 高調波/低調波関係チェック
   
4. 補正適用
   - 7%削減係数（correctionFactor = 0.93）
   - 有効範囲制限（60-160 SPM）
```

### 静止状態検出
```dart
// 標準偏差による判定
double stdDev = _calculateStandardDeviation(recentMagnitudes);
if (stdDev < minStdDev) {
  // 静止状態と判定
  _isStatic = true;
  _currentSpm = 0.0;
  _stepCount = 0;
}
```

## 3. メトロノーム実装

### リポジトリパターン
```dart
// domain/repositories/metronome_repository.dart
abstract class MetronomeRepository {
  Future<Result<Unit>> start({required double bpm});
  Future<Result<Unit>> stop();
  Future<Result<Unit>> changeTempo(double bpm);
  Stream<double> get tempoStream;
  bool get isPlaying;
}
```

### Flutterメトロノーム実装

#### 波形生成
```dart
// data/repositories/flutter_metronome_repository_impl.dart
// クリック音パラメータ
const frequency = 900.0;        // Hz
const duration = 0.025;         // 秒
const fadeInDuration = 0.002;   // 秒
const fadeOutDuration = 0.015;  // 秒
const amplitude = 0.3;          // 音量

// 正弦波生成 + エンベロープ適用
for (int i = 0; i < totalSamples; i++) {
  double t = i / sampleRate;
  double envelope = _calculateEnvelope(t);
  double sample = amplitude * envelope * sin(2 * pi * frequency * t);
}
```

#### タイミング制御
```dart
// 高精度タイマー使用（1ms精度）
Timer(Duration(milliseconds: delayMillis), () {
  _playClick();
  _beatStreamController.add(null);
  _scheduleNextBeat();
});

// ドリフト防止
_nextBeatTime = _startTime! + 
  (beatInterval * (_currentBeat + 1));
```

### ネイティブメトロノーム実装

#### iOS実装 (NativeMetronomePlugin.swift)
```swift
// ios/Runner/NativeMetronomePlugin.swift
// 超低遅延設定
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playback, 
  mode: .default, 
  options: [.mixWithOthers])
try session.setPreferredIOBufferDuration(0.002) // 2ms

// リアルタイムオーディオノード
let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
  // サンプル精度のタイミング制御
  // ミューテックス保護された状態管理
}
```

#### Android実装 (NativeMetronomePlugin.kt)
```kotlin
// android/app/src/main/kotlin/com/example/accelerater_app/NativeMetronomePlugin.kt
// AudioTrack静的モード
val audioTrack = AudioTrack.Builder()
    .setAudioAttributes(audioAttributes)
    .setAudioFormat(audioFormat)
    .setBufferSizeInBytes(bufferSize)
    .setTransferMode(AudioTrack.MODE_STATIC)
    .build()
    
// 高精度タイマー
val handler = Handler(handlerThread.looper)
handler.postDelayed(beatRunnable, delayMillis)
```

## 4. データ同期と記録

### タイムスタンプ管理
```dart
// 全データに統一タイムスタンプ
DateTime now = DateTime.now();
int timestamp = now.millisecondsSinceEpoch;

// models/sensor_data.dart - M5SensorData
M5SensorData {
  timestamp: timestamp,  // デバイス側タイムスタンプ
  // アプリ側で受信時刻も記録
}
```

### 実験データ記録
```dart
// services/experiment_controller.dart: recordTimeSeriesData()メソッド
Map<String, dynamic> dataPoint = {
  'timestamp': DateTime.now().toIso8601String(),
  'elapsed_seconds': elapsedSeconds,
  'phase': currentPhase.name,
  'current_spm': currentSpm,
  'target_spm': targetSpm,
  'heart_rate': heartRate,
  'step_count': stepCount,
  'reliability': reliability,
  'cv': currentCV,              // 変動係数
  'response_time': responseTime, // 反応時間
  'additional_data': {
    'spm_history': spmHistory,
    'stable_seconds': stableSeconds,
    'is_stable': isStable,
    'use_adaptive_control': useAdaptiveControl,
    // その他メタデータ
  }
};
```

### 加速度データ完全記録
```dart
// models/sensor_data.dart - AccelerometerDataBuffer
class AccelerometerDataBuffer {
  final int maxBufferSize = 360000; // 1時間分（100Hz × 3600秒）
  
  // リングバッファによる効率的なメモリ管理
  void add(M5SensorData data) {
    if (_buffer.length >= maxBufferSize) {
      _buffer.removeAt(0);
    }
    _buffer.add(data);
  }
  
  // CSV出力機能
  String toCsv() {
    // ヘッダーとデータをCSV形式で出力
  }
}
```

## 5. エラーハンドリングとフォールバック

### Result型によるエラーハンドリング
```dart
// core/utils/result.dart
typedef Result<T> = Either<AppException, T>;

// 使用例（domain/usecases/bluetooth/connect_device_usecase.dart）
final result = await repository.connectDevice(deviceId);
result.fold(
  (error) => _handleError(error),
  (success) => _handleSuccess(),
);
```

### BLE接続管理
```dart
// data/repositories/bluetooth_repository_impl.dart
// 自動再接続とタイムアウト処理
device.connectionState.listen((state) {
  if (state == BluetoothConnectionState.disconnected) {
    // 再接続試行
    _attemptReconnection();
  }
});

// タイムアウト設定
await device.connect(timeout: Duration(seconds: 10));
```

### メトロノームフォールバック
```dart
// presentation/providers/metronome_providers.dart
try {
  // ネイティブメトロノーム試行
  await nativeMetronomeRepository.start(bpm: targetBpm);
} catch (e) {
  // Flutterメトロノームへフォールバック
  await flutterMetronomeRepository.start(bpm: targetBpm);
}
```

## 6. パフォーマンス最適化

### メモリ管理
- センサーデータバッファ: 最大600サンプル（10秒分）通常解析用
- 加速度データ完全記録: 最大360,000サンプル（1時間分）研究用
- 心拍数履歴: 最新3-5値のみ保持
- FFT計算: 1秒ごとのスライディングウィンドウ

### 並行処理
- BLEデータ受信: 独立ストリーム
- UI更新: 別タイマー（1秒間隔）
- オーディオ生成: ネイティブスレッド
- データ保存: 非同期処理

### バッテリー最適化
- バックグラウンドサービス対応
- 画面オフ時の継続動作
- 効率的なBLEスキャン設定

## 7. 状態管理アーキテクチャ

### Riverpodプロバイダー構造
```dart
// presentation/providers/service_providers.dart
final bluetoothRepositoryProvider = Provider<BluetoothRepository>((ref) {
  return BluetoothRepositoryImpl();
});

// presentation/providers/usecase_providers.dart
final connectDeviceUseCaseProvider = Provider<ConnectDeviceUseCase>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return ConnectDeviceUseCase(repository);
});

// presentation/providers/bluetooth_providers.dart
final bluetoothScanProvider = StreamProvider<List<BluetoothDevice>>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.scanDevices();
});
```

### 依存性注入フロー
1. リポジトリの提供（serviceProviders）
2. ユースケースの注入（usecaseProviders）
3. UI状態の管理（各機能のproviders）

この構造により、テスタビリティと保守性が向上しています。