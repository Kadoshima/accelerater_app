import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../interfaces/sensor_interface.dart';
import '../models/sensor_data_models.dart';
import '../../plugins/research_plugin.dart';
import '../../../services/ble_service.dart';
import '../../../models/sensor_data.dart' as legacy;

/// Adapter to wrap BLE devices as generic sensors
class BLESensorAdapter extends ISensor<IMUData> {
  final BluetoothDevice device;
  final BleService bleService;
  final String _id;
  final ValueNotifier<SensorStatus> _status = ValueNotifier(SensorStatus.disconnected);
  final StreamController<IMUData> _dataController = StreamController<IMUData>.broadcast();
  
  StreamSubscription? _bleSubscription;
  SensorConfiguration _configuration;
  
  BLESensorAdapter({
    required this.device,
    required this.bleService,
    String? id,
    SensorConfiguration? initialConfig,
  }) : _id = id ?? 'ble_${device.id.id}',
       _configuration = initialConfig ?? const SensorConfiguration(samplingRate: 100.0);
  
  @override
  String get id => _id;
  
  @override
  SensorType get type => SensorType.accelerometer; // Primary type for IMU
  
  @override
  ValueNotifier<SensorStatus> get status => _status;
  
  @override
  SensorCapabilities get capabilities => const SensorCapabilities(
    minSamplingRate: 10.0,
    maxSamplingRate: 200.0,
    availableSamplingRates: [10, 25, 50, 100, 200],
    supportsBatching: false,
    supportsCalibration: true,
    additionalCapabilities: {
      'hasGyroscope': true,
      'hasMagnetometer': true,
      'protocol': 'BLE',
    },
  );
  
  @override
  SensorInfo get info => SensorInfo(
    name: device.name,
    manufacturer: 'M5Stack',
    model: 'M5StickC Plus 2',
    additionalInfo: {
      'macAddress': device.id.id,
      'rssi': device.rssi,
    },
  );
  
  @override
  Future<void> connect() async {
    if (_status.value == SensorStatus.connected || 
        _status.value == SensorStatus.collecting) {
      return;
    }
    
    _status.value = SensorStatus.connecting;
    
    try {
      await bleService.connectToDevice(device);
      _status.value = SensorStatus.connected;
    } catch (e) {
      _status.value = SensorStatus.error;
      throw Exception('Failed to connect to BLE device: $e');
    }
  }
  
  @override
  Future<void> disconnect() async {
    await stopDataCollection();
    
    try {
      await device.disconnect();
      _status.value = SensorStatus.disconnected;
    } catch (e) {
      _status.value = SensorStatus.error;
      throw Exception('Failed to disconnect from BLE device: $e');
    }
  }
  
  @override
  Future<void> startDataCollection() async {
    if (_status.value != SensorStatus.connected) {
      throw StateError('Sensor must be connected before starting data collection');
    }
    
    // Subscribe to BLE data stream
    _bleSubscription = bleService.sensorDataStream.listen(
      (legacyData) {
        // Convert legacy M5SensorData to generic IMUData
        final imuData = _convertLegacyData(legacyData);
        _dataController.add(imuData);
      },
      onError: (error) {
        debugPrint('BLE data stream error: $error');
        _status.value = SensorStatus.error;
      },
    );
    
    _status.value = SensorStatus.collecting;
  }
  
  @override
  Future<void> stopDataCollection() async {
    await _bleSubscription?.cancel();
    _bleSubscription = null;
    
    if (_status.value == SensorStatus.collecting) {
      _status.value = SensorStatus.connected;
    }
  }
  
  @override
  Stream<IMUData> get dataStream => _dataController.stream;
  
  @override
  Future<void> configure(SensorConfiguration config) async {
    _configuration = config;
    
    // If connected, apply configuration to device
    if (_status.value == SensorStatus.connected || 
        _status.value == SensorStatus.collecting) {
      // TODO: Send configuration to BLE device
      debugPrint('Configuring BLE sensor with sampling rate: ${config.samplingRate}Hz');
    }
  }
  
  @override
  SensorConfiguration get currentConfiguration => _configuration;
  
  @override
  Future<CalibrationResult> calibrate() async {
    if (_status.value != SensorStatus.connected) {
      return const CalibrationResult(
        success: false,
        errorMessage: 'Sensor must be connected for calibration',
      );
    }
    
    // TODO: Implement actual calibration
    debugPrint('Calibrating BLE sensor...');
    
    return const CalibrationResult(
      success: true,
      calibrationData: {
        'accelerometerOffset': {'x': 0.0, 'y': 0.0, 'z': 0.0},
        'gyroscopeOffset': {'x': 0.0, 'y': 0.0, 'z': 0.0},
      },
    );
  }
  
  @override
  Future<bool> isAvailable() async {
    try {
      return await device.canSendWriteWithoutResponse;
    } catch (e) {
      return false;
    }
  }
  
  /// Convert legacy M5SensorData to generic IMUData
  IMUData _convertLegacyData(legacy.M5SensorData legacyData) {
    return IMUData(
      timestamp: DateTime.now(), // Legacy data doesn't have timestamp
      accelerometer: AccelerometerData(
        timestamp: DateTime.now(),
        x: legacyData.accelerometerX,
        y: legacyData.accelerometerY,
        z: legacyData.accelerometerZ,
      ),
      gyroscope: GyroscopeData(
        timestamp: DateTime.now(),
        x: legacyData.gyroscopeX,
        y: legacyData.gyroscopeY,
        z: legacyData.gyroscopeZ,
      ),
      magnetometer: MagnetometerData(
        timestamp: DateTime.now(),
        x: legacyData.magnetometerX,
        y: legacyData.magnetometerY,
        z: legacyData.magnetometerZ,
      ),
    );
  }
  
  void dispose() {
    _bleSubscription?.cancel();
    _dataController.close();
    _status.dispose();
  }
}