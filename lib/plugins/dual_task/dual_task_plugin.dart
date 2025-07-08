import 'package:flutter/material.dart';
import '../../core/plugins/research_plugin.dart';
import '../../presentation/screens/dual_task_menu_screen.dart';
import '../../core/sensors/models/sensor_data_models.dart';

/// 二重課題プロトコル研究プラグイン
class DualTaskPlugin extends ResearchPlugin {
  Map<String, dynamic>? _config;
  
  @override
  String get id => 'dual_task_protocol';

  @override
  String get name => '可変難度・二重課題プロトコル';

  @override
  String get description => '適応的リズム歩行支援における認知負荷が歩行安定性と同期パフォーマンスに与える影響の評価';

  @override
  String get version => '1.0.0';

  @override
  List<SensorType> get requiredSensors => [
    SensorType.accelerometer,
    SensorType.gyroscope,
    SensorType.heartRate,
    SensorType.microphone,
  ];

  @override
  List<SensorType> get optionalSensors => [
    SensorType.magnetometer,
    SensorType.gps,
  ];

  @override
  Future<void> initialize() async {
    // 二重課題プロトコルの初期化
    // 必要なサービスの初期化はDualTaskExperimentScreenで行う
  }

  @override
  Future<void> dispose() async {
    // リソースのクリーンアップ
    // 実験中のサービスがあれば停止
  }

  @override
  Widget buildConfigScreen(BuildContext context) {
    // 設定画面は現在DualTaskMenuScreenに統合されている
    return const Center(
      child: Text('二重課題プロトコルの設定はメニュー画面で行います'),
    );
  }

  @override
  Widget buildExperimentScreen(BuildContext context) {
    return const DualTaskMenuScreen();
  }

  @override
  DataProcessor createDataProcessor() {
    return DualTaskDataProcessor();
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
    List<String> errors = [];
    List<String> warnings = [];

    // 必要なセンサーの確認
    // 実際の実装では、センサーマネージャーを使用してチェック
    
    // 権限の確認
    // 音声認識・録音権限
    // Bluetooth権限（心拍計）
    
    if (errors.isEmpty) {
      return ValidationResult(
        isValid: true,
        warnings: warnings,
      );
    } else {
      return ValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }
  }
}

/// 二重課題プロトコル用データプロセッサー
class DualTaskDataProcessor extends DataProcessor {
  Map<String, dynamic> _configuration = {};

  @override
  Stream<ProcessedData> process(Stream<SensorData> input) {
    // センサーデータの処理
    return input.map((data) {
      // 二重課題プロトコル固有の処理
      Map<String, dynamic> processedData = {};
      
      if (data is AccelerometerData) {
        processedData.addAll({
          'accX': data.x,
          'accY': data.y,
          'accZ': data.z,
          'sensorId': data.sensorId,
        });
      } else if (data is IMUData) {
        if (data.accelerometer != null) {
          processedData.addAll({
            'accX': data.accelerometer!.x,
            'accY': data.accelerometer!.y,
            'accZ': data.accelerometer!.z,
          });
        }
        if (data.gyroscope != null) {
          processedData.addAll({
            'gyroX': data.gyroscope!.x,
            'gyroY': data.gyroscope!.y,
            'gyroZ': data.gyroscope!.z,
          });
        }
        processedData['sensorId'] = data.sensorId;
      }
      
      return DualTaskProcessedData(
        timestamp: data.timestamp,
        data: processedData,
      );
    });
  }

  @override
  Map<String, dynamic> get configuration => _configuration;

  @override
  void updateConfiguration(Map<String, dynamic> config) {
    _configuration = config;
  }
}

/// 二重課題プロトコル用処理済みデータ
class DualTaskProcessedData extends ProcessedData {
  const DualTaskProcessedData({
    required super.timestamp,
    required super.data,
  });
}