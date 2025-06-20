import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../services/ble_service.dart';
import '../../../models/sensor_data.dart';
import '../interfaces/sensor_interface.dart';
import 'm5_sensor_adapter.dart';

/// BLEサービスとセンサーマネージャーを統合するアダプター
class BLEServiceAdapter {
  final BleService _bleService;
  final ISensorManager _sensorManager;
  final Map<String, M5BLESensor> _imuSensors = {};
  final Map<String, M5HeartRateSensor> _heartRateSensors = {};
  
  StreamSubscription<M5SensorData>? _dataSubscription;
  
  BLEServiceAdapter({
    required BleService bleService,
    required ISensorManager sensorManager,
  }) : _bleService = bleService,
       _sensorManager = sensorManager;
  
  /// 初期化
  Future<void> initialize() async {
    // BLEサービスのセンサーデータストリームを購読
    _dataSubscription = _bleService.sensorDataStream.listen(
      _handleSensorData,
      onError: (error) {
        debugPrint('BLEServiceAdapter error: $error');
      },
    );
    debugPrint('BLEServiceAdapter initialized');
  }
  
  /// センサーデータを処理
  void _handleSensorData(M5SensorData m5Data) {
    final deviceId = m5Data.device;
    
    // IMUデータの場合
    if (m5Data.type == 'raw' || m5Data.type == 'imu') {
      // IMUセンサーがまだ登録されていない場合は作成
      if (!_imuSensors.containsKey(deviceId)) {
        _createAndRegisterIMUSensor(deviceId);
      }
    }
    // 心拍データの場合
    else if (m5Data.type == 'bpm') {
      // 心拍センサーがまだ登録されていない場合は作成
      if (!_heartRateSensors.containsKey(deviceId)) {
        _createAndRegisterHeartRateSensor(deviceId);
      }
    }
  }
  
  /// IMUセンサーを自動作成して登録
  void _createAndRegisterIMUSensor(String deviceId) {
    final sensor = createIMUSensor(
      deviceId: deviceId,
      dataStream: _bleService.sensorDataStream,
    );
    
    // 自動接続
    sensor.connect().then((_) {
      debugPrint('IMU sensor $deviceId connected');
    }).catchError((error) {
      debugPrint('Failed to connect IMU sensor $deviceId: $error');
    });
  }
  
  /// 心拍センサーを自動作成して登録
  void _createAndRegisterHeartRateSensor(String deviceId) {
    final sensor = createHeartRateSensor(
      deviceId: deviceId,
      dataStream: _bleService.sensorDataStream,
    );
    
    // 自動接続
    sensor.connect().then((_) {
      debugPrint('Heart rate sensor $deviceId connected');
    }).catchError((error) {
      debugPrint('Failed to connect heart rate sensor $deviceId: $error');
    });
  }
  
  /// M5SensorDataストリームからセンサーを作成
  /// 
  /// この実装は、BleServiceがM5SensorDataストリームを
  /// 提供するように拡張された後に使用されます
  M5BLESensor createIMUSensor({
    required String deviceId,
    required Stream<M5SensorData> dataStream,
  }) {
    final sensor = M5BLESensor(
      deviceId: deviceId,
      m5DataStream: dataStream
          .where((data) => data.device == deviceId && 
                         (data.type == 'raw' || data.type == 'imu')),
    );
    
    _imuSensors[deviceId] = sensor;
    _sensorManager.registerSensor(sensor);
    
    return sensor;
  }
  
  /// 心拍センサーを作成
  M5HeartRateSensor createHeartRateSensor({
    required String deviceId,
    required Stream<M5SensorData> dataStream,
  }) {
    final sensor = M5HeartRateSensor(
      deviceId: deviceId,
      m5DataStream: dataStream
          .where((data) => data.device == deviceId && data.type == 'bpm'),
    );
    
    _heartRateSensors[deviceId] = sensor;
    _sensorManager.registerSensor(sensor);
    
    return sensor;
  }
  
  /// 特定のデバイスを切断
  Future<void> disconnectDevice(String deviceId) async {
    // IMUセンサーの切断
    final imuSensor = _imuSensors[deviceId];
    if (imuSensor != null) {
      await imuSensor.disconnect();
      _sensorManager.unregisterSensor(imuSensor.id);
      imuSensor.dispose();
      _imuSensors.remove(deviceId);
    }
    
    // 心拍センサーの切断
    final heartRateSensor = _heartRateSensors[deviceId];
    if (heartRateSensor != null) {
      await heartRateSensor.disconnect();
      _sensorManager.unregisterSensor(heartRateSensor.id);
      heartRateSensor.dispose();
      _heartRateSensors.remove(deviceId);
    }
  }
  
  /// すべてのセンサーを切断
  Future<void> disconnectAll() async {
    // すべてのIMUセンサーを切断
    for (final sensor in _imuSensors.values) {
      await sensor.disconnect();
      _sensorManager.unregisterSensor(sensor.id);
      sensor.dispose();
    }
    _imuSensors.clear();
    
    // すべての心拍センサーを切断
    for (final sensor in _heartRateSensors.values) {
      await sensor.disconnect();
      _sensorManager.unregisterSensor(sensor.id);
      sensor.dispose();
    }
    _heartRateSensors.clear();
  }
  
  /// 現在接続されているBLEデバイス
  BluetoothDevice? get connectedDevice => _bleService.connectedDevice;
  
  /// リソースを解放
  Future<void> dispose() async {
    await _dataSubscription?.cancel();
    await disconnectAll();
  }
}