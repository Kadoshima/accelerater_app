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

##### `BluetoothDeviceEntity` (domain/entities/bluetooth_device.dart)
```dart
@freezed
class BluetoothDeviceEntity with _$BluetoothDeviceEntity {
  const factory BluetoothDeviceEntity({
    required String id,
    required String name,
    required BluetoothDeviceType type,
    @Default(false) bool isConnected,
    int? rssi,
    @Default({}) Map<String, List<int>> manufacturerData,
    @Default([]) List<String> serviceUuids,
  }) = _BluetoothDeviceEntity;
}

// デバイスタイプ
enum BluetoothDeviceType {
  heartRate,
  imuSensor,
  unknown,
}

// スキャン状態
enum BluetoothScanState {
  idle,
  scanning,
}

// 接続状態
enum DeviceConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}
```

##### `HeartRateData` (domain/entities/heart_rate_data.dart)
```dart
@freezed
class HeartRateData with _$HeartRateData {
  const factory HeartRateData({
    required int heartRate,
    required DateTime timestamp,
    required HeartRateDataSource source,
    int? energyExpended,
    List<int>? rrIntervals,
    double? confidence,
  }) = _HeartRateData;
}

// 心拍数データのソース
enum HeartRateDataSource {
  standardBle,     // 標準BLEプロトコル
  huaweiProtocol,  // Huawei独自プロトコル
  appleWatch,      // Apple Watch
  other,           // その他
}
```

#### Repositories (Interfaces)

##### `BluetoothRepository` (domain/repositories/bluetooth_repository.dart)
```dart
abstract class BluetoothRepository {
  // Bluetoothの利用可能状態を取得
  Stream<bool> get isAvailable;
  
  // スキャン状態を取得
  Stream<BluetoothScanState> get scanState;
  
  // 接続済みデバイスのリストを取得
  Stream<List<BluetoothDeviceEntity>> get connectedDevices;
  
  // デバイスをスキャン
  Future<Result<void>> startScan({
    Duration timeout = const Duration(seconds: 5),
    List<String>? serviceUuids,
  });
  
  // スキャンを停止
  Future<Result<void>> stopScan();
  
  // スキャン結果を取得
  Stream<List<BluetoothDeviceEntity>> get scanResults;
  
  // デバイスに接続
  Future<Result<void>> connectDevice(String deviceId);
  
  // デバイスから切断
  Future<Result<void>> disconnectDevice(String deviceId);
  
  // 心拍数データのストリームを取得
  Stream<Result<HeartRateData>> getHeartRateStream(String deviceId);
  
  // IMUセンサーデータのストリームを取得
  Stream<Result<M5SensorData>> getImuSensorStream(String deviceId);
  
  // デバイスの接続状態を取得
  Stream<DeviceConnectionState> getConnectionState(String deviceId);
}
```

##### `MetronomeRepository` (domain/repositories/metronome_repository.dart)
```dart
abstract class MetronomeRepository {
  // メトロノームを初期化
  Future<Result<void>> initialize();
  
  // メトロノームを開始
  Future<Result<void>> start({double? bpm});
  
  // メトロノームを停止
  Future<Result<void>> stop();
  
  // テンポを変更
  Future<Result<void>> changeTempo(double bpm);
  
  // バイブレーション設定を変更
  Future<Result<void>> setVibration(bool enabled);
  
  // 現在の再生状態を取得
  bool get isPlaying;
  
  // 現在のBPMを取得
  double get currentBpm;
  
  // バイブレーション設定を取得
  bool get vibrationEnabled;
  
  // ビートイベントのストリーム
  Stream<void> get beatStream;
  
  // メトロノームの状態ストリーム
  Stream<MetronomeState> get stateStream;
  
  // リソースを解放
  void dispose();
}

// メトロノームの状態
class MetronomeState {
  final bool isPlaying;
  final double bpm;
  final bool vibrationEnabled;
  final DateTime? lastBeatTime;
  final int beatCount;
}
```

##### `ExperimentRepository` (domain/repositories/experiment_repository.dart)
```dart
abstract class ExperimentRepository {
  // 実験セッションを開始
  Future<Result<ExperimentSession>> startExperiment({
    required ExperimentCondition condition,
    required String subjectId,
    Map<String, dynamic>? subjectData,
    InductionVariation inductionVariation = InductionVariation.increasing,
    Map<AdvancedExperimentPhase, Duration>? customPhaseDurations,
    double inductionStepPercent = 0.05,
    int inductionStepCount = 4,
  });
  
  // 実験を停止
  Future<Result<void>> stopExperiment();
  
  // 現在の実験セッションを取得
  ExperimentSession? get currentSession;
  
  // 実験セッションのストリーム
  Stream<ExperimentSession?> get sessionStream;
  
  // フェーズ変更のストリーム
  Stream<AdvancedExperimentPhase> get phaseStream;
  
  // 実験データを記録
  Future<Result<void>> recordTimeSeriesData({
    required double currentSpm,
    required double targetSpm,
    required double followRate,
    Map<String, dynamic>? additionalData,
  });
  
  // 次のフェーズに進む
  Future<Result<void>> advanceToNextPhase();
  
  // 主観評価を設定
  Future<Result<void>> setSubjectiveEvaluation(SubjectiveEvaluation evaluation);
  
  // セッションデータを保存
  Future<Result<void>> saveSessionData(ExperimentSession session);
  
  // 保存された実験データを取得
  Future<Result<List<ExperimentSession>>> getStoredSessions();
  
  // 特定のセッションデータを取得
  Future<Result<ExperimentSession>> getSessionById(String sessionId);
  
  // 実験データをエクスポート
  Future<Result<String>> exportSessionData(String sessionId, ExportFormat format);
}

// エクスポート形式
enum ExportFormat { csv, json }
```

##### `GaitAnalysisRepository` (domain/repositories/gait_analysis_repository.dart)
```dart
abstract class GaitAnalysisRepository {
  // センサーデータを追加
  void addSensorData(M5SensorData data);
  
  // 現在のSPM（歩数/分）を取得
  double get currentSpm;
  
  // 歩数カウントを取得
  int get stepCount;
  
  // 信頼性スコアを取得
  double get reliability;
  
  // 静止状態かどうかを取得
  bool get isStatic;
  
  // SPM履歴を取得
  List<double> get spmHistory;
  
  // 歩行解析状態のストリーム
  Stream<GaitAnalysisState> get stateStream;
  
  // 解析をリセット
  void reset();
  
  // 歩行の安定性を評価
  GaitStability evaluateStability({
    required double targetSpm,
    required Duration evaluationPeriod,
  });
}

// 歩行解析の状態
class GaitAnalysisState {
  final double currentSpm;
  final int stepCount;
  final double reliability;
  final bool isStatic;
  final List<double> recentSpmValues;
  final DateTime? lastUpdate;
}

// 歩行の安定性評価
class GaitStability {
  final bool isStable;
  final int stableSeconds;
  final double averageSpm;
  final double spmVariance;
  final double followRate;
}
```

#### Use Cases

##### `ConnectDeviceUseCase` (domain/usecases/bluetooth/connect_device_usecase.dart)
```dart
class ConnectDeviceUseCase {
  final BluetoothRepository _repository;
  
  // デバイスに接続
  Future<Result<void>> connect(String deviceId) {
    return _repository.connectDevice(deviceId);
  }
  
  // デバイスから切断
  Future<Result<void>> disconnect(String deviceId) {
    return _repository.disconnectDevice(deviceId);
  }
  
  // 接続状態を監視
  Stream<DeviceConnectionState> getConnectionState(String deviceId) {
    return _repository.getConnectionState(deviceId);
  }
  
  // 接続済みデバイスを監視
  Stream<List<BluetoothDeviceEntity>> get connectedDevices => 
      _repository.connectedDevices;
}
```

##### `GetHeartRateUseCase` (domain/usecases/bluetooth/get_heart_rate_usecase.dart)
```dart
class GetHeartRateUseCase {
  final BluetoothRepository _repository;
  
  // 心拍数データストリームを取得
  Stream<Result<HeartRateData>> getHeartRateStream(String deviceId) {
    return _repository.getHeartRateStream(deviceId);
  }
  
  // 心拍数データの検証
  bool isValidHeartRate(int heartRate) {
    return heartRate >= 40 && heartRate <= 220;
  }
  
  // 平均心拍数を計算
  double calculateAverageHeartRate(List<HeartRateData> data) {
    if (data.isEmpty) return 0;
    final sum = data.fold<double>(0, (sum, item) => sum + item.heartRate);
    return sum / data.length;
  }
  
  // 心拍数の変動を計算
  double calculateHeartRateVariability(List<HeartRateData> data) {
    if (data.length < 2) return 0;
    // RR間隔の差分から変動を計算
    return variability;
  }
}
```

##### `ScanDevicesUseCase` (domain/usecases/bluetooth/scan_devices_usecase.dart)
```dart
class ScanDevicesUseCase {
  final BluetoothRepository _repository;
  
  // デバイススキャンを開始
  Future<Result<void>> startScan({
    Duration timeout = const Duration(seconds: 5),
    List<String>? serviceUuids,
  }) {
    return _repository.startScan(
      timeout: timeout,
      serviceUuids: serviceUuids,
    );
  }
  
  // スキャンを停止
  Future<Result<void>> stopScan() {
    return _repository.stopScan();
  }
  
  // スキャン結果を監視
  Stream<List<BluetoothDeviceEntity>> get scanResults => 
      _repository.scanResults;
}
```

##### `GetImuDataUseCase` (domain/usecases/bluetooth/get_imu_data_usecase.dart)
```dart
class GetImuDataUseCase {
  final BluetoothRepository _repository;
  
  // IMUセンサーデータストリームを取得
  Stream<Result<M5SensorData>> getImuSensorStream(String deviceId) {
    return _repository.getImuSensorStream(deviceId);
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
// Bluetoothリポジトリのプロバイダー
final bluetoothRepositoryProvider = Provider<BluetoothRepository>((ref) {
  return BluetoothRepositoryImpl();
});

// Bluetoothの利用可能状態を監視
final bluetoothAvailableProvider = StreamProvider<bool>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.isAvailable;
});

// スキャン状態を監視
final bluetoothScanStateProvider = StreamProvider<BluetoothScanState>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.scanState;
});

// スキャン結果を監視
final bluetoothScanResultsProvider = StreamProvider<List<BluetoothDeviceEntity>>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.scanResults;
});

// 接続済みデバイスを監視
final connectedDevicesProvider = StreamProvider<List<BluetoothDeviceEntity>>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.connectedDevices;
});

// 心拍数データを監視（デバイスIDごと）
final heartRateStreamProvider = StreamProvider.family<Result<HeartRateData>, String>((ref, deviceId) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.getHeartRateStream(deviceId);
});

// IMUセンサーデータを監視（デバイスIDごと）
final imuSensorStreamProvider = StreamProvider.family<Result<M5SensorData>, String>((ref, deviceId) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.getImuSensorStream(deviceId);
});

// 心拍数履歴を管理
final heartRateHistoryProvider = StateNotifierProvider<HeartRateHistoryNotifier, List<HeartRateData>>((ref) {
  return HeartRateHistoryNotifier();
});
```

##### `metronomeProviders.dart`
```dart
// メトロノームタイプ（Native or Flutter）
enum MetronomeType { flutter, native }

// 使用するメトロノームタイプ
final metronomeTypeProvider = StateProvider<MetronomeType>((ref) => MetronomeType.native);

// Flutterメトロノームリポジトリ
final flutterMetronomeRepositoryProvider = Provider<MetronomeRepository>((ref) {
  final repository = FlutterMetronomeRepositoryImpl();
  ref.onDispose(() => repository.dispose());
  return repository;
});

// ネイティブメトロノームリポジトリ
final nativeMetronomeRepositoryProvider = Provider<MetronomeRepository>((ref) {
  final repository = NativeMetronomeRepositoryImpl();
  ref.onDispose(() => repository.dispose());
  return repository;
});

// 現在のメトロノームリポジトリ
final metronomeRepositoryProvider = Provider<MetronomeRepository>((ref) {
  final type = ref.watch(metronomeTypeProvider);
  return type == MetronomeType.native
      ? ref.watch(nativeMetronomeRepositoryProvider)
      : ref.watch(flutterMetronomeRepositoryProvider);
});

// メトロノーム状態管理
final currentBpmProvider = StateProvider<double>((ref) => 120.0);
final isPlayingProvider = StateProvider<bool>((ref) => false);
final vibrationEnabledProvider = StateProvider<bool>((ref) => true);

// メトロノームコントローラー
final metronomeControllerProvider = Provider<MetronomeController>((ref) {
  final repository = ref.watch(metronomeRepositoryProvider);
  return MetronomeController(ref: ref, repository: repository);
});
```

##### `gaitAnalysisProviders.dart`
```dart
// 歩行分析サービス
final gaitAnalysisServiceProvider = Provider<GaitAnalysisService>((ref) {
  return GaitAnalysisService();
});

// 現在のSPM（歩数/分）
final currentSpmProvider = StateProvider<double>((ref) => 0.0);

// 歩数カウント
final stepCountProvider = StateProvider<int>((ref) => 0);

// 信頼性スコア
final reliabilityProvider = StateProvider<double>((ref) => 0.0);
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
// 結果型のエイリアス（fpdartのEitherを使用）
typedef Result<T> = Either<AppException, T>;

// ヘルパー関数
class Results {
  // 成功結果を生成
  static Result<T> success<T>(T value) => Right(value);
  
  // 失敗結果を生成
  static Result<T> failure<T>(AppException exception) => Left(exception);
  
  // 非同期処理を安全に実行
  static Future<Result<T>> tryAsync<T>(
    Future<T> Function() operation, {
    AppException Function(dynamic error, StackTrace? stackTrace)? onError,
  });
  
  // 同期処理を安全に実行
  static Result<T> trySync<T>(
    T Function() operation, {
    AppException Function(dynamic error, StackTrace? stackTrace)? onError,
  });
}

// 使用例
final result = await repository.connectDevice(deviceId);
result.fold(
  (error) => showError(error.message),
  (success) => showSuccess(),
);

// Resultsヘルパーの使用例
return Results.tryAsync(() async {
  await device.connect();
  logger.info('Connected to device');
}, onError: (error, stackTrace) {
  return DeviceConnectionException(
    message: 'Failed to connect to device',
    originalError: error,
  );
});
```

### 例外クラス (core/errors/app_exceptions.dart)
```dart
// 基底例外クラス
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  
  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });
}

// 派生例外クラス
class BluetoothException extends AppException {
  const BluetoothException({
    required super.message,
    super.code,
    super.originalError,
  });
}

class DeviceConnectionException extends BluetoothException {
  const DeviceConnectionException({
    required super.message,
    super.code,
    super.originalError,
  });
}

class DataParsingException extends AppException {
  const DataParsingException({
    required super.message,
    super.code,
    super.originalError,
  });
}

class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code,
    super.originalError,
  });
}

class NetworkException extends AppException {
  final int? statusCode;
  
  const NetworkException({
    required super.message,
    this.statusCode,
    super.code,
    super.originalError,
  });
}

class PermissionException extends AppException {
  final String permissionType;
  
  const PermissionException({
    required super.message,
    required this.permissionType,
    super.code,
    super.originalError,
  });
}

class ExperimentException extends AppException {
  const ExperimentException({
    required super.message,
    super.code,
    super.originalError,
  });
}

class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code,
    super.originalError,
  });
}
```

## 定数定義

### BLE定数 (core/constants/ble_constants.dart)
```dart
class BleConstants {
  // 心拍数サービス
  static const String heartRateServiceUuid = "0000180d-0000-1000-8000-00805f9b34fb";
  static const String heartRateMeasurementCharUuid = "00002a37-0000-1000-8000-00805f9b34fb";
  
  // IMUサービス（M5Stick）
  static const String imuServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String imuCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String m5StickDeviceName = "M5StickIMU";
  
  // Huaweiプロトコル
  static const int huaweiHeaderByte1 = 0x5a;
  static const int huaweiHeaderByte2 = 0x00;
  static const int huaweiHeartRateCommand = 0x09;
  
  // 心拍数の有効範囲
  static const int minHeartRate = 30;
  static const int maxHeartRate = 220;
  
  // タイムアウトと間隔
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration scanTimeout = Duration(seconds: 5);
  static const Duration heartRateUpdateInterval = Duration(seconds: 1);
  static const Duration dataRecordingInterval = Duration(seconds: 2);
  
  // 重複除去のしきい値
  static const Duration heartRateDuplicateThreshold = Duration(milliseconds: 500);
}
```

## ユーティリティ

### ロガー (core/utils/logger_service.dart)
```dart
// シングルトンロガーサービス
class LoggerService {
  void debug(dynamic message, [dynamic error, StackTrace? stackTrace]);
  void info(dynamic message, [dynamic error, StackTrace? stackTrace]);
  void warning(dynamic message, [dynamic error, StackTrace? stackTrace]);
  void error(dynamic message, [dynamic error, StackTrace? stackTrace]);
  void wtf(dynamic message, [dynamic error, StackTrace? stackTrace]);
}

// グローバルロガーインスタンス
final logger = LoggerService();

// 使用例
logger.info('Bluetooth scan started');
logger.error('Device connection failed', error, stackTrace);
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