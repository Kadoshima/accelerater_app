# API リファレンス

## 更新日: 2024/06/04

このドキュメントは、歩行解析・音響フィードバックシステムの主要なAPIとクラスの仕様を記載しています。

## アーキテクチャ概要

本システムは、Clean Architectureに基づいたレイヤード構造を採用しています：

- **Presentation層**: UI、状態管理（Riverpod）
- **Domain層**: ビジネスロジック、エンティティ、ユースケース
- **Data層**: リポジトリ実装、データソース
- **Core層**: 共通機能、定数、ユーティリティ

## 主要コンポーネント

### 1. Domain層

#### Entities

##### `BluetoothDevice` (domain/entities/bluetooth_device.dart)
```dart
@freezed
class BluetoothDevice with _$BluetoothDevice {
  const factory BluetoothDevice({
    required String id,
    required String name,
    required DeviceType type,
    @Default(false) bool isConnected,
    @Default(null) int? rssi,
  }) = _BluetoothDevice;
}
```

##### `HeartRateData` (domain/entities/heart_rate_data.dart)
```dart
@freezed
class HeartRateData with _$HeartRateData {
  const factory HeartRateData({
    required int value,
    required DateTime timestamp,
    @Default(null) int? energyExpended,
    @Default(null) List<int>? rrIntervals,
  }) = _HeartRateData;
}
```

#### Repositories (Interfaces)

##### `BluetoothRepository` (domain/repositories/bluetooth_repository.dart)
```dart
abstract class BluetoothRepository {
  Stream<List<BluetoothDevice>> scanDevices();
  Future<Result<Unit>> connectDevice(String deviceId);
  Future<Result<Unit>> disconnectDevice(String deviceId);
  Stream<HeartRateData> getHeartRateStream(String deviceId);
  Stream<M5SensorData> getSensorDataStream(String deviceId);
}
```

##### `MetronomeRepository` (domain/repositories/metronome_repository.dart)
```dart
abstract class MetronomeRepository {
  Future<Result<Unit>> start({required double bpm});
  Future<Result<Unit>> stop();
  Future<Result<Unit>> changeTempo(double bpm);
  Stream<double> get tempoStream;
  bool get isPlaying;
}
```

#### Use Cases

##### `ConnectDeviceUseCase` (domain/usecases/bluetooth/connect_device_usecase.dart)
```dart
class ConnectDeviceUseCase {
  final BluetoothRepository _repository;
  
  Future<Result<Unit>> call(String deviceId) {
    return _repository.connectDevice(deviceId);
  }
}
```

### 2. Data層

#### Models

##### `M5SensorData` (models/sensor_data.dart)
```dart
class M5SensorData {
  final String device;
  final int timestamp;
  final String type;
  final Map<String, dynamic> data;
  
  // アクセサメソッド
  double? get accX;
  double? get accY;
  double? get accZ;
  double? get magnitude;
  
  // CSV出力用
  List<dynamic> toCsvRow();
  static List<String> getCsvHeaders();
}
```

##### `AccelerometerDataBuffer` (models/sensor_data.dart)
```dart
class AccelerometerDataBuffer {
  final int maxBufferSize; // デフォルト: 360000 (1時間分)
  
  void add(M5SensorData data);
  void clear();
  List<M5SensorData> get data;
  List<M5SensorData> getDataInTimeRange(DateTime start, DateTime end);
  double get estimatedMemoryUsageMB;
}
```

### 3. Services層

#### `GaitAnalysisService` (utils/gait_analysis_service.dart)

FFTベースの歩行解析サービス。

**主要メソッド:**
```dart
class GaitAnalysisService {
  // データ追加と解析
  void addSensorData(M5SensorData sensorData);
  
  // プロパティ
  double get currentSpm;      // 現在の歩行ペース
  int get stepCount;          // 累積歩数
  double get reliability;     // 信頼性スコア (0-1)
  M5SensorData? get latestSensorData;  // 最新のセンサーデータ
}
```

#### `AdaptiveTempoController` (services/adaptive_tempo_controller.dart)

個人の反応に応じた適応的テンポ制御。

**主要メソッド:**
```dart
class AdaptiveTempoController {
  // 初期化
  void initialize(double baselineSpm);
  
  // テンポ更新
  double updateTargetSpm({
    required double currentSpm,
    required double currentCv,
    required DateTime timestamp,
  });
  
  // パラメータ学習
  void learnFromSession(List<Map<String, dynamic>> sessionData);
  
  // パラメータのインポート/エクスポート
  Map<String, dynamic> exportPersonalParameters();
  void importPersonalParameters(Map<String, dynamic> params);
}
```

#### `ExperimentController` (services/experiment_controller.dart)

実験セッションの管理。

**主要メソッド:**
```dart
class ExperimentController {
  // 実験開始
  Future<void> startExperiment({
    required ExperimentCondition condition,
    required String subjectId,
    ExperimentType experimentType = ExperimentType.traditional,
    List<RandomPhaseInfo>? randomPhaseSequence,
  });
  
  // 実験停止
  Future<void> stopExperiment();
  
  // 手動フェーズ進行
  void advanceToNextPhase();
  
  // 状態取得
  double getCurrentSpm();
  bool isStable();
  int getStableSeconds();
}
```

### 4. Presentation層

#### Providers (状態管理)

##### `bluetoothProviders.dart`
```dart
// デバイススキャン
final bluetoothScanProvider = StreamProvider<List<BluetoothDevice>>(...);

// 接続状態
final bluetoothConnectionProvider = StateNotifierProvider<...>(...);

// 心拍数データ
final heartRateProvider = StreamProvider<HeartRateData?>(...);
```

##### `gaitAnalysisProviders.dart`
```dart
// 歩行分析サービス
final gaitAnalysisServiceProvider = Provider<GaitAnalysisService>(...);

// 現在のSPM
final currentSpmProvider = StateProvider<double>(...);

// 歩数カウント
final stepCountProvider = StateProvider<int>(...);
```

## 実験モデル

### `ExperimentCondition`
```dart
class ExperimentCondition {
  final String id;
  final String name;
  final bool useMetronome;
  final bool explicitInstruction;
  final String description;
  final bool useAdaptiveControl;  // 個別対応機能
}
```

### `ExperimentType`
```dart
enum ExperimentType {
  traditional,  // 従来型（順序固定）
  randomOrder,  // ランダム順序（反応研究用）
}
```

### `RandomPhaseType`
```dart
enum RandomPhaseType {
  freeWalk,      // 自由歩行
  pitchKeep,     // ピッチ維持
  pitchIncrease, // ピッチ上昇
}
```

## エラーハンドリング

### Result型 (core/utils/result.dart)
```dart
typedef Result<T> = Either<AppException, T>;

// 使用例
final result = await repository.connectDevice(deviceId);
result.fold(
  (error) => showError(error.message),
  (success) => showSuccess(),
);
```

### 例外クラス (core/errors/app_exceptions.dart)
```dart
abstract class AppException implements Exception {
  final String message;
  final String? code;
}

class BluetoothException extends AppException {...}
class ConnectionException extends AppException {...}
class DataException extends AppException {...}
```

## 定数定義

### BLE定数 (core/constants/ble_constants.dart)
```dart
class BleConstants {
  // 標準サービス
  static const heartRateServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
  static const heartRateMeasurementUuid = '00002a37-0000-1000-8000-00805f9b34fb';
  
  // M5Stick IMUサービス
  static const imuServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const imuCharacteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
}
```

## ユーティリティ

### ロガー (core/utils/logger_service.dart)
```dart
class LoggerService {
  static void d(String message);  // デバッグ
  static void i(String message);  // 情報
  static void w(String message);  // 警告
  static void e(String message, [dynamic error, StackTrace? stackTrace]);  // エラー
}
```

### 実験ユーティリティ (utils/experiment_utils.dart)
```dart
class ExperimentUtils {
  // ランダムフェーズシーケンス生成
  static List<RandomPhaseInfo> generateRandomPhaseSequence({
    required int phaseCount,
    Duration? minPhaseDuration,
    Duration? maxPhaseDuration,
  });
  
  // 反応研究用条件生成
  static ExperimentCondition createReactionStudyCondition({
    bool useAdaptiveControl = false,
  });
}
```