# 技術詳細ドキュメント

## 1. BLE通信プロトコル

### 心拍数データ受信

#### 標準BLE心拍数サービス
```dart
// main.dart: _setupHeartRateMonitoring() (行 3953-4057)
const String HEART_RATE_SERVICE_UUID = "0000180d-0000-1000-8000-00805f9b34fb";
const String HEART_RATE_MEASUREMENT_CHAR_UUID = "00002a37-0000-1000-8000-00805f9b34fb";

// データフォーマット（標準BLE）
// バイト0: フラグ（ビット0 = 心拍数フォーマット）
// - 0: 8ビット値（バイト1）
// - 1: 16ビット値（バイト1-2）
// 残りのバイト: オプション（エネルギー消費、RR間隔など）
```

#### Huaweiカスタムプロトコル
```dart
// main.dart: _processHeartRateData() (行 4058-4118)
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
// main.dart: _startListeningToSensor() (行 4119-4156)
const String IMU_SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String IMU_CHAR_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

// JSONフォーマット例
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
// gait_analysis_service.dart
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
// gait_analysis_service.dart: _processFFT() (行 130-242)
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

### Flutterメトロノーム

#### 波形生成
```dart
// metronome.dart: _generateClick() (行 236-254)
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
// metronome.dart: _scheduleBeat() (行 177-208)
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

### ネイティブメトロノーム（iOS）

#### オーディオエンジン設定
```swift
// NativeMetronomePlugin.swift (行 84-127)
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

#### 波形レンダリング
```swift
// NativeMetronomePlugin.swift: generateClickWaveform() (行 225-250)
// プリレンダリングによる低遅延
for i in 0..<clickSamples.count {
  let t = Double(i) / sampleRate
  let amplitude = 0.5
  let frequency = 900.0
  
  // エクスポネンシャル減衰
  let decayRate = 40.0
  let envelope = exp(-decayRate * t)
  
  clickSamples[i] = Float(amplitude * envelope * 
    sin(2.0 * .pi * frequency * t))
}
```

## 4. データ同期と記録

### タイムスタンプ管理
```dart
// 全データに統一タイムスタンプ
DateTime now = DateTime.now();
int timestamp = now.millisecondsSinceEpoch;

// センサーデータ同期
M5SensorData {
  timestamp: timestamp,  // デバイス側タイムスタンプ
  // アプリ側で受信時刻も記録
}
```

### 実験データ記録
```dart
// experiment_controller.dart: recordTimeSeriesData() (行 134-156)
Map<String, dynamic> dataPoint = {
  'timestamp': DateTime.now().toIso8601String(),
  'elapsed_seconds': elapsedSeconds,
  'phase': currentPhase.name,
  'current_spm': currentSpm,
  'target_spm': targetSpm,
  'heart_rate': heartRate,
  'step_count': stepCount,
  'reliability': reliability,
  'additional_data': {
    'spm_history': spmHistory,
    'stable_seconds': stableSeconds,
    'is_stable': isStable,
    // その他メタデータ
  }
};
```

## 5. エラーハンドリングとフォールバック

### BLE接続管理
```dart
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
// main.dart: _togglePlayback() (行 1405-1438)
try {
  // ネイティブメトロノーム試行
  await _nativeMetronome.start();
} catch (e) {
  // Flutterメトロノームへフォールバック
  await _metronome.start();
}
```

## 6. パフォーマンス最適化

### メモリ管理
- センサーデータバッファ: 最大600サンプル（10秒分）
- 心拍数履歴: 最新3-5値のみ保持
- FFT計算: 1秒ごとのスライディングウィンドウ

### 並行処理
- BLEデータ受信: 独立ストリーム
- UI更新: 別タイマー（1秒間隔）
- オーディオ生成: ネイティブスレッド

### バッテリー最適化
- バックグラウンドサービス対応
- 画面オフ時の継続動作
- 効率的なBLEスキャン設定