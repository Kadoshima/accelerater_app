import 'package:flutter/material.dart';
import '../../core/plugins/research_plugin.dart';
import '../../core/sensors/interfaces/sensor_interface.dart';
import 'services/gait_analysis_service.dart';
import 'services/adaptive_tempo_controller.dart';
import 'services/metronome.dart';
import 'services/native_metronome.dart';
import 'presentation/screens/gait_analysis_screen.dart';
import '../../models/sensor_data.dart';
import '../../core/sensors/models/sensor_data_models.dart';

/// 歩行解析研究プラグイン
class GaitAnalysisPlugin extends ResearchPlugin {
  late final GaitAnalysisService _gaitAnalysisService;
  late final AdaptiveTempoController _adaptiveTempoController;
  late final Metronome _metronome;
  late final NativeMetronome _nativeMetronome;

  @override
  String get id => 'gait_analysis';

  @override
  String get name => '歩行解析と適応的リズム誘導';

  @override
  String get description => '加速度センサーとメトロノームを使用した歩行パターンの解析と改善';

  @override
  String get version => '1.0.0';

  String get author => 'Research Team';

  List<String> get requiredPermissions => [
    'bluetooth',
    'location',
    'storage',
    'microphone',
  ];

  @override
  List<SensorType> get requiredSensors => [
    SensorType.accelerometer,
    SensorType.gyroscope,
    SensorType.heartRate,
  ];

  List<String> get supportedPlatforms => ['iOS', 'Android'];

  Map<String, dynamic>? _config;
  
  @override
  Future<void> initialize() async {
    // サービスの初期化
    _gaitAnalysisService = GaitAnalysisService(
      totalDataSeconds: _config?['totalDataSeconds'] ?? 6,
      windowSizeSeconds: _config?['windowSizeSeconds'] ?? 3,
      slideIntervalSeconds: _config?['slideIntervalSeconds'] ?? 1,
      smoothingFactor: _config?['smoothingFactor'] ?? 0.8,
      minSpm: _config?['minSpm'] ?? 40,
      maxSpm: _config?['maxSpm'] ?? 180,
      minReliability: _config?['minReliability'] ?? 0.3,
      staticThreshold: _config?['staticThreshold'] ?? 0.2,
      useSingleAxisOnly: _config?['useSingleAxisOnly'] ?? true,
      verticalAxis: _config?['verticalAxis'] ?? 'z',
    );

    _adaptiveTempoController = AdaptiveTempoController();
    _metronome = Metronome();
    _nativeMetronome = NativeMetronome();

    await _metronome.initialize();
    await _nativeMetronome.initialize();
  }

  // これらのメソッドは ResearchPlugin インターフェースにないため削除
  // start() と stop() の代わりに initialize() と dispose() を使用

  @override
  Future<void> dispose() async {
    _metronome.dispose();
    _nativeMetronome.dispose();
  }

  @override
  Widget buildConfigScreen(BuildContext context) {
    // TODO: Implement configuration screen
    return const Center(
      child: Text('Configuration screen for Gait Analysis'),
    );
  }

  @override
  Widget buildExperimentScreen(BuildContext context) {
    return GaitAnalysisScreen(
      gaitAnalysisService: _gaitAnalysisService,
      adaptiveTempoController: _adaptiveTempoController,
      metronome: _metronome,
      nativeMetronome: _nativeMetronome,
    );
  }

  @override
  DataProcessor createDataProcessor() {
    // TODO: Implement data processor
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> exportSettings() {
    return _config ?? {};
  }

  @override
  void importSettings(Map<String, dynamic> settings) {
    _config = settings;
  }

  @override
  ValidationResult validate() {
    // TODO: Implement validation
    return const ValidationResult(
      isValid: true,
      errors: [],
    );
  }

  // これらのメソッドは ResearchPlugin インターフェースにないため削除

  // これらのメソッドは ResearchPlugin インターフェースにないため削除
  // buildUI と buildSettingsUI の代わりに buildConfigScreen と buildExperimentScreen を使用

  Stream<Map<String, dynamic>> get dataStream {
    // リアルタイムデータストリーム
    // TODO: GaitAnalysisServiceにanalysisResultStreamを実装するか、
    // ステップカウントから擬似的なストリームを生成する
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) => {
        'spm': _gaitAnalysisService.currentSpm,
        'reliability': _gaitAnalysisService.reliability,
        'stepCount': _gaitAnalysisService.stepCount,
      },
    );
  }

  Future<List<Map<String, dynamic>>> exportData({
    required DateTime startTime,
    required DateTime endTime,
    String? format,
  }) async {
    // データエクスポート機能
    // TODO: 実装予定
    return [];
  }

  void handleSensorData(SensorData data) {
    // センサーデータを受け取って処理
    // SensorDataのサブクラスをチェックして処理
    if (data is AccelerometerData) {
      // AccelerometerDataをM5SensorDataに変換して処理
      final m5Data = M5SensorData(
        device: data.sensorId,
        timestamp: data.timestamp.millisecondsSinceEpoch,
        type: 'imu',
        data: {
          'accX': data.x,
          'accY': data.y,
          'accZ': data.z,
        },
      );
      _gaitAnalysisService.addSensorData(m5Data);
    } else if (data is IMUData && data.accelerometer != null) {
      // IMUDataから加速度データを抽出
      final acc = data.accelerometer!;
      final m5Data = M5SensorData(
        device: data.sensorId,
        timestamp: data.timestamp.millisecondsSinceEpoch,
        type: 'imu',
        data: {
          'accX': acc.x,
          'accY': acc.y,
          'accZ': acc.z,
        },
      );
      _gaitAnalysisService.addSensorData(m5Data);
    }
  }

  // プラグイン固有のメソッド
  GaitAnalysisService get gaitAnalysisService => _gaitAnalysisService;
  AdaptiveTempoController get adaptiveTempoController => _adaptiveTempoController;
  Metronome get metronome => _metronome;
  NativeMetronome get nativeMetronome => _nativeMetronome;
}