import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../models/sensor_data.dart';
import '../interfaces/sensor_interface.dart';
import '../models/sensor_data_models.dart';
import '../../plugins/research_plugin.dart';

/// M5SensorDataを汎用SensorDataに変換するアダプター
class M5SensorAdapter {
  /// M5SensorDataからAccelerometerDataに変換
  static AccelerometerData? toAccelerometerData(M5SensorData m5Data) {
    if (m5Data.type != 'raw' && m5Data.type != 'imu') return null;
    
    final accX = m5Data.accX;
    final accY = m5Data.accY;
    final accZ = m5Data.accZ;
    
    if (accX == null || accY == null || accZ == null) return null;
    
    return AccelerometerData(
      x: accX,
      y: accY,
      z: accZ,
      timestamp: DateTime.fromMillisecondsSinceEpoch(m5Data.timestamp),
      sensorId: '${m5Data.device}_accelerometer',
      metadata: {
        'device': m5Data.device,
        'type': m5Data.type,
        'originalTimestamp': m5Data.timestamp,
      },
    );
  }
  
  /// M5SensorDataからGyroscopeDataに変換
  static GyroscopeData? toGyroscopeData(M5SensorData m5Data) {
    if (m5Data.type != 'raw' && m5Data.type != 'imu') return null;
    
    final gyroX = m5Data.gyroX;
    final gyroY = m5Data.gyroY;
    final gyroZ = m5Data.gyroZ;
    
    if (gyroX == null || gyroY == null || gyroZ == null) return null;
    
    return GyroscopeData(
      x: gyroX,
      y: gyroY,
      z: gyroZ,
      timestamp: DateTime.fromMillisecondsSinceEpoch(m5Data.timestamp),
      sensorId: '${m5Data.device}_gyroscope',
      metadata: {
        'device': m5Data.device,
        'type': m5Data.type,
        'originalTimestamp': m5Data.timestamp,
      },
    );
  }
  
  /// M5SensorDataからHeartRateDataに変換
  static HeartRateData? toHeartRateData(M5SensorData m5Data) {
    if (m5Data.type != 'bpm') return null;
    
    final bpm = m5Data.bpm;
    if (bpm == null) return null;
    
    return HeartRateData(
      bpm: bpm.toInt(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(m5Data.timestamp),
      sensorId: '${m5Data.device}_heartrate',
      confidence: 1.0, // M5データには信頼度がないので1.0とする
      rrIntervals: m5Data.lastInterval != null ? [m5Data.lastInterval!] : [],
      metadata: {
        'device': m5Data.device,
        'type': m5Data.type,
        'originalTimestamp': m5Data.timestamp,
        'lastInterval': m5Data.lastInterval,
      },
    );
  }
  
  /// M5SensorDataからIMUDataに変換
  static IMUData? toIMUData(M5SensorData m5Data) {
    if (m5Data.type != 'raw' && m5Data.type != 'imu') return null;
    
    final accelData = toAccelerometerData(m5Data);
    final gyroData = toGyroscopeData(m5Data);
    
    if (accelData == null && gyroData == null) return null;
    
    return IMUData(
      accelerometer: accelData,
      gyroscope: gyroData,
      magnetometer: null, // M5Stackはマグネトメーターデータを送信していない
      timestamp: DateTime.fromMillisecondsSinceEpoch(m5Data.timestamp),
      sensorId: '${m5Data.device}_imu',
      metadata: {
        'device': m5Data.device,
        'type': m5Data.type,
        'originalTimestamp': m5Data.timestamp,
      },
    );
  }
}

/// M5Stack BLEデバイスを汎用センサーインターフェースでラップするクラス
class M5BLESensor implements ISensor<IMUData> {
  final String deviceId;
  final Stream<M5SensorData> m5DataStream;
  final ValueNotifier<SensorStatus> _status = ValueNotifier(SensorStatus.disconnected);
  final StreamController<IMUData> _dataController = StreamController<IMUData>.broadcast();
  StreamSubscription<M5SensorData>? _m5Subscription;
  
  SensorConfiguration _currentConfiguration = const SensorConfiguration(
    samplingRate: 100.0,
    enableBatching: false,
    batchSize: 1,
  );
  
  M5BLESensor({
    required this.deviceId,
    required this.m5DataStream,
  });
  
  @override
  String get id => deviceId;
  
  @override
  SensorType get type => SensorType.accelerometer; // IMUの主要タイプ
  
  @override
  ValueNotifier<SensorStatus> get status => _status;
  
  @override
  Stream<IMUData> get dataStream => _dataController.stream;
  
  @override
  SensorCapabilities get capabilities => const SensorCapabilities(
    minSamplingRate: 1.0,
    maxSamplingRate: 100.0,
    availableSamplingRates: [1.0, 10.0, 50.0, 100.0],
    supportsBatching: false,
    supportsCalibration: false,
    additionalCapabilities: {
      'imuType': '6-axis',
      'hasGyroscope': true,
      'hasMagnetometer': false,
    },
  );
  
  @override
  SensorInfo get info => const SensorInfo(
    name: 'M5Stack IMU',
    manufacturer: 'M5Stack',
    model: 'MPU6886',
    version: '1.0',
    additionalInfo: {
      'interface': 'BLE',
      'axes': 6,
    },
  );
  
  @override
  SensorConfiguration get currentConfiguration => _currentConfiguration;
  
  @override
  Future<void> configure(SensorConfiguration config) async {
    _currentConfiguration = config;
    // M5センサーの設定変更は現在サポートされていない
    debugPrint('M5 sensor configuration update not supported');
  }
  
  @override
  Future<void> connect() async {
    if (_status.value == SensorStatus.connected || 
        _status.value == SensorStatus.collecting) {
      return;
    }
    
    _status.value = SensorStatus.connecting;
    
    try {
      // M5データストリームを購読
      _m5Subscription = m5DataStream.listen(
        (m5Data) {
          final imuData = M5SensorAdapter.toIMUData(m5Data);
          if (imuData != null) {
            _dataController.add(imuData);
          }
        },
        onError: (error) {
          _status.value = SensorStatus.error;
          _dataController.addError(error);
        },
      );
      
      _status.value = SensorStatus.connected;
    } catch (e) {
      _status.value = SensorStatus.error;
      rethrow;
    }
  }
  
  @override
  Future<void> disconnect() async {
    await _m5Subscription?.cancel();
    _m5Subscription = null;
    _status.value = SensorStatus.disconnected;
  }
  
  @override
  Future<void> startDataCollection() async {
    if (_status.value != SensorStatus.connected) {
      throw StateError('Sensor must be connected before starting collection');
    }
    _status.value = SensorStatus.collecting;
  }
  
  @override
  Future<void> stopDataCollection() async {
    if (_status.value == SensorStatus.collecting) {
      _status.value = SensorStatus.connected;
    }
  }
  
  @override
  Future<bool> isAvailable() async {
    // BLE接続の可用性はBLEサービスで管理
    return true;
  }
  
  @override
  Future<CalibrationResult> calibrate() async {
    // M5センサーのキャリブレーションは未実装
    debugPrint('M5 sensor calibration not implemented');
    return const CalibrationResult(
      success: false,
      errorMessage: 'Calibration not supported for M5 sensor',
    );
  }
  
  void dispose() {
    disconnect();
    _dataController.close();
    _status.dispose();
  }
}

/// 心拍センサー用のアダプター
class M5HeartRateSensor implements ISensor<HeartRateData> {
  final String deviceId;
  final Stream<M5SensorData> m5DataStream;
  final ValueNotifier<SensorStatus> _status = ValueNotifier(SensorStatus.disconnected);
  final StreamController<HeartRateData> _dataController = StreamController<HeartRateData>.broadcast();
  StreamSubscription<M5SensorData>? _m5Subscription;
  
  SensorConfiguration _currentConfiguration = const SensorConfiguration(
    samplingRate: 1.0,
    enableBatching: false,
    batchSize: 1,
  );
  
  M5HeartRateSensor({
    required this.deviceId,
    required this.m5DataStream,
  });
  
  @override
  String get id => '${deviceId}_heartrate';
  
  @override
  SensorType get type => SensorType.heartRate;
  
  @override
  ValueNotifier<SensorStatus> get status => _status;
  
  @override
  Stream<HeartRateData> get dataStream => _dataController.stream;
  
  @override
  SensorCapabilities get capabilities => const SensorCapabilities(
    minSamplingRate: 1.0,
    maxSamplingRate: 1.0,
    availableSamplingRates: [1.0],
    supportsBatching: false,
    supportsCalibration: false,
    additionalCapabilities: {
      'supportsRRIntervals': true,
    },
  );
  
  @override
  SensorInfo get info => const SensorInfo(
    name: 'Heart Rate Monitor',
    manufacturer: 'Various',
    model: 'BLE HRM',
    version: '1.0',
    additionalInfo: {
      'interface': 'BLE',
      'protocol': 'Heart Rate Service',
    },
  );
  
  @override
  SensorConfiguration get currentConfiguration => _currentConfiguration;
  
  @override
  Future<void> configure(SensorConfiguration config) async {
    _currentConfiguration = config;
    // 心拍センサーの設定変更は現在サポートされていない
    debugPrint('Heart rate sensor configuration update not supported');
  }
  
  @override
  Future<void> connect() async {
    if (_status.value == SensorStatus.connected || 
        _status.value == SensorStatus.collecting) {
      return;
    }
    
    _status.value = SensorStatus.connecting;
    
    try {
      // M5データストリームを購読（心拍データのみフィルタリング）
      _m5Subscription = m5DataStream
          .where((m5Data) => m5Data.type == 'bpm')
          .listen(
        (m5Data) {
          final heartRateData = M5SensorAdapter.toHeartRateData(m5Data);
          if (heartRateData != null) {
            _dataController.add(heartRateData);
          }
        },
        onError: (error) {
          _status.value = SensorStatus.error;
          _dataController.addError(error);
        },
      );
      
      _status.value = SensorStatus.connected;
    } catch (e) {
      _status.value = SensorStatus.error;
      rethrow;
    }
  }
  
  @override
  Future<void> disconnect() async {
    await _m5Subscription?.cancel();
    _m5Subscription = null;
    _status.value = SensorStatus.disconnected;
  }
  
  @override
  Future<void> startDataCollection() async {
    if (_status.value != SensorStatus.connected) {
      throw StateError('Sensor must be connected before starting collection');
    }
    _status.value = SensorStatus.collecting;
  }
  
  @override
  Future<void> stopDataCollection() async {
    if (_status.value == SensorStatus.collecting) {
      _status.value = SensorStatus.connected;
    }
  }
  
  @override
  Future<bool> isAvailable() async {
    return true;
  }
  
  @override
  Future<CalibrationResult> calibrate() async {
    debugPrint('Heart rate sensor calibration not implemented');
    return const CalibrationResult(
      success: false,
      errorMessage: 'Calibration not supported for heart rate sensor',
    );
  }
  
  void dispose() {
    disconnect();
    _dataController.close();
    _status.dispose();
  }
}