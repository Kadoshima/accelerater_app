import 'package:flutter/material.dart';
import '../../core/plugins/research_plugin.dart';
import '../../core/sensors/interfaces/sensor_interface.dart';
import 'services/gait_analysis_service.dart';
import 'services/adaptive_tempo_controller.dart';
import 'services/metronome.dart';
import 'services/native_metronome.dart';
import 'presentation/screens/gait_analysis_screen.dart';

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

  @override
  String get author => 'Research Team';

  @override
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

  @override
  List<String> get supportedPlatforms => ['iOS', 'Android'];

  @override
  Future<void> initialize(Map<String, dynamic>? config) async {
    // サービスの初期化
    _gaitAnalysisService = GaitAnalysisService(
      totalDataSeconds: config?['totalDataSeconds'] ?? 6,
      windowSizeSeconds: config?['windowSizeSeconds'] ?? 3,
      slideIntervalSeconds: config?['slideIntervalSeconds'] ?? 1,
      smoothingFactor: config?['smoothingFactor'] ?? 0.8,
      minSpm: config?['minSpm'] ?? 40,
      maxSpm: config?['maxSpm'] ?? 180,
      minReliability: config?['minReliability'] ?? 0.3,
      staticThreshold: config?['staticThreshold'] ?? 0.2,
      useSingleAxisOnly: config?['useSingleAxisOnly'] ?? true,
      verticalAxis: config?['verticalAxis'] ?? 'z',
    );

    _adaptiveTempoController = AdaptiveTempoController();
    _metronome = Metronome();
    _nativeMetronome = NativeMetronome();

    await _metronome.initialize();
    await _nativeMetronome.initialize();
  }

  @override
  Future<void> start() async {
    // 必要に応じてサービスを開始
    debugPrint('GaitAnalysisPlugin started');
  }

  @override
  Future<void> stop() async {
    await _metronome.stop();
    await _nativeMetronome.stop();
    debugPrint('GaitAnalysisPlugin stopped');
  }

  @override
  Future<void> dispose() async {
    await _metronome.dispose();
    await _nativeMetronome.dispose();
  }

  @override
  Map<String, dynamic> getConfiguration() {
    return {
      'totalDataSeconds': _gaitAnalysisService.totalDataSeconds,
      'windowSizeSeconds': _gaitAnalysisService.windowSizeSeconds,
      'smoothingFactor': _gaitAnalysisService.smoothingFactor,
      'minSpm': _gaitAnalysisService.minSpm,
      'maxSpm': _gaitAnalysisService.maxSpm,
    };
  }

  @override
  void updateConfiguration(Map<String, dynamic> config) {
    // 動的な設定更新が必要な場合に実装
  }

  @override
  bool validateConfiguration(Map<String, dynamic> config) {
    // 設定の妥当性をチェック
    final totalDataSeconds = config['totalDataSeconds'];
    final windowSizeSeconds = config['windowSizeSeconds'];
    
    if (totalDataSeconds != null && windowSizeSeconds != null) {
      if (totalDataSeconds < windowSizeSeconds) {
        return false;
      }
    }
    
    return true;
  }

  @override
  Widget buildUI(BuildContext context) {
    return GaitAnalysisScreen(
      gaitAnalysisService: _gaitAnalysisService,
      adaptiveTempoController: _adaptiveTempoController,
      metronome: _metronome,
      nativeMetronome: _nativeMetronome,
    );
  }

  @override
  Widget? buildSettingsUI(BuildContext context) {
    // 設定画面を実装
    return null; // TODO: 実装予定
  }

  @override
  Stream<Map<String, dynamic>> get dataStream {
    // リアルタイムデータストリーム
    return _gaitAnalysisService.analysisResultStream.map((result) => {
      'spm': result.spm,
      'reliability': result.reliability,
      'stepCount': result.stepCount,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> exportData({
    required DateTime startTime,
    required DateTime endTime,
    String? format,
  }) async {
    // データエクスポート機能
    // TODO: 実装予定
    return [];
  }

  @override
  void handleSensorData(SensorData data) {
    // センサーデータを受け取って処理
    if (data.sensorId.contains('accelerometer')) {
      // GaitAnalysisServiceに渡す処理を実装
    }
  }

  // プラグイン固有のメソッド
  GaitAnalysisService get gaitAnalysisService => _gaitAnalysisService;
  AdaptiveTempoController get adaptiveTempoController => _adaptiveTempoController;
  Metronome get metronome => _metronome;
  NativeMetronome get nativeMetronome => _nativeMetronome;
}