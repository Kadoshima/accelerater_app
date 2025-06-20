import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../interfaces/sensor_interface.dart';
import '../models/sensor_data_models.dart';
import '../../plugins/research_plugin.dart';

/// Adapter for phone's built-in accelerometer
class PhoneAccelerometerSensor extends ISensor<AccelerometerData> {
  final String _id = 'phone_accelerometer';
  final ValueNotifier<SensorStatus> _status = ValueNotifier(SensorStatus.disconnected);
  final StreamController<AccelerometerData> _dataController = 
      StreamController<AccelerometerData>.broadcast();
  
  StreamSubscription? _sensorSubscription;
  SensorConfiguration _configuration;
  
  PhoneAccelerometerSensor({
    SensorConfiguration? initialConfig,
  }) : _configuration = initialConfig ?? const SensorConfiguration(samplingRate: 100.0);
  
  @override
  String get id => _id;
  
  @override
  SensorType get type => SensorType.accelerometer;
  
  @override
  ValueNotifier<SensorStatus> get status => _status;
  
  @override
  SensorCapabilities get capabilities => const SensorCapabilities(
    minSamplingRate: 1.0,
    maxSamplingRate: 200.0,
    supportsBatching: false,
    supportsCalibration: false,
    additionalCapabilities: {
      'isBuiltIn': true,
      'requiresPermission': false,
    },
  );
  
  @override
  SensorInfo get info => const SensorInfo(
    name: 'Phone Accelerometer',
    manufacturer: 'Device Manufacturer',
    model: 'Built-in',
    additionalInfo: {
      'type': 'MEMS',
    },
  );
  
  @override
  Future<void> connect() async {
    // Phone sensors don't need explicit connection
    _status.value = SensorStatus.connected;
  }
  
  @override
  Future<void> disconnect() async {
    await stopDataCollection();
    _status.value = SensorStatus.disconnected;
  }
  
  @override
  Future<void> startDataCollection() async {
    if (_status.value != SensorStatus.connected) {
      throw StateError('Sensor must be connected before starting data collection');
    }
    
    // Subscribe to accelerometer events
    _sensorSubscription = accelerometerEvents.listen(
      (AccelerometerEvent event) {
        final data = AccelerometerData(
          timestamp: DateTime.now(),
          x: event.x,
          y: event.y,
          z: event.z,
        );
        _dataController.add(data);
      },
      onError: (error) {
        debugPrint('Accelerometer stream error: $error');
        _status.value = SensorStatus.error;
      },
    );
    
    _status.value = SensorStatus.collecting;
  }
  
  @override
  Future<void> stopDataCollection() async {
    await _sensorSubscription?.cancel();
    _sensorSubscription = null;
    
    if (_status.value == SensorStatus.collecting) {
      _status.value = SensorStatus.connected;
    }
  }
  
  @override
  Stream<AccelerometerData> get dataStream => _dataController.stream;
  
  @override
  Future<void> configure(SensorConfiguration config) async {
    _configuration = config;
    // Note: Phone sensors typically don't allow sampling rate configuration
    debugPrint('Phone accelerometer configured (sampling rate is device-dependent)');
  }
  
  @override
  SensorConfiguration get currentConfiguration => _configuration;
  
  @override
  Future<CalibrationResult> calibrate() async {
    // Phone sensors are typically pre-calibrated
    return const CalibrationResult(
      success: false,
      errorMessage: 'Phone sensors do not support manual calibration',
    );
  }
  
  @override
  Future<bool> isAvailable() async {
    try {
      // Try to get one reading to check availability
      await accelerometerEvents.first
          .timeout(const Duration(seconds: 2));
      return true;
    } catch (e) {
      return false;
    }
  }
  
  void dispose() {
    _sensorSubscription?.cancel();
    _dataController.close();
    _status.dispose();
  }
}

/// Adapter for phone's built-in gyroscope
class PhoneGyroscopeSensor extends ISensor<GyroscopeData> {
  final String _id = 'phone_gyroscope';
  final ValueNotifier<SensorStatus> _status = ValueNotifier(SensorStatus.disconnected);
  final StreamController<GyroscopeData> _dataController = 
      StreamController<GyroscopeData>.broadcast();
  
  StreamSubscription? _sensorSubscription;
  SensorConfiguration _configuration;
  
  PhoneGyroscopeSensor({
    SensorConfiguration? initialConfig,
  }) : _configuration = initialConfig ?? const SensorConfiguration(samplingRate: 100.0);
  
  @override
  String get id => _id;
  
  @override
  SensorType get type => SensorType.gyroscope;
  
  @override
  ValueNotifier<SensorStatus> get status => _status;
  
  @override
  SensorCapabilities get capabilities => const SensorCapabilities(
    minSamplingRate: 1.0,
    maxSamplingRate: 200.0,
    supportsBatching: false,
    supportsCalibration: false,
    additionalCapabilities: {
      'isBuiltIn': true,
      'requiresPermission': false,
    },
  );
  
  @override
  SensorInfo get info => const SensorInfo(
    name: 'Phone Gyroscope',
    manufacturer: 'Device Manufacturer',
    model: 'Built-in',
    additionalInfo: {
      'type': 'MEMS',
    },
  );
  
  @override
  Future<void> connect() async {
    _status.value = SensorStatus.connected;
  }
  
  @override
  Future<void> disconnect() async {
    await stopDataCollection();
    _status.value = SensorStatus.disconnected;
  }
  
  @override
  Future<void> startDataCollection() async {
    if (_status.value != SensorStatus.connected) {
      throw StateError('Sensor must be connected before starting data collection');
    }
    
    _sensorSubscription = gyroscopeEvents.listen(
      (GyroscopeEvent event) {
        final data = GyroscopeData(
          timestamp: DateTime.now(),
          x: event.x,
          y: event.y,
          z: event.z,
        );
        _dataController.add(data);
      },
      onError: (error) {
        debugPrint('Gyroscope stream error: $error');
        _status.value = SensorStatus.error;
      },
    );
    
    _status.value = SensorStatus.collecting;
  }
  
  @override
  Future<void> stopDataCollection() async {
    await _sensorSubscription?.cancel();
    _sensorSubscription = null;
    
    if (_status.value == SensorStatus.collecting) {
      _status.value = SensorStatus.connected;
    }
  }
  
  @override
  Stream<GyroscopeData> get dataStream => _dataController.stream;
  
  @override
  Future<void> configure(SensorConfiguration config) async {
    _configuration = config;
    debugPrint('Phone gyroscope configured (sampling rate is device-dependent)');
  }
  
  @override
  SensorConfiguration get currentConfiguration => _configuration;
  
  @override
  Future<CalibrationResult> calibrate() async {
    return const CalibrationResult(
      success: false,
      errorMessage: 'Phone sensors do not support manual calibration',
    );
  }
  
  @override
  Future<bool> isAvailable() async {
    try {
      await gyroscopeEvents.first
          .timeout(const Duration(seconds: 2));
      return true;
    } catch (e) {
      return false;
    }
  }
  
  void dispose() {
    _sensorSubscription?.cancel();
    _dataController.close();
    _status.dispose();
  }
}

/// Adapter for phone's built-in magnetometer
class PhoneMagnetometerSensor extends ISensor<MagnetometerData> {
  final String _id = 'phone_magnetometer';
  final ValueNotifier<SensorStatus> _status = ValueNotifier(SensorStatus.disconnected);
  final StreamController<MagnetometerData> _dataController = 
      StreamController<MagnetometerData>.broadcast();
  
  StreamSubscription? _sensorSubscription;
  SensorConfiguration _configuration;
  
  PhoneMagnetometerSensor({
    SensorConfiguration? initialConfig,
  }) : _configuration = initialConfig ?? const SensorConfiguration(samplingRate: 100.0);
  
  @override
  String get id => _id;
  
  @override
  SensorType get type => SensorType.magnetometer;
  
  @override
  ValueNotifier<SensorStatus> get status => _status;
  
  @override
  SensorCapabilities get capabilities => const SensorCapabilities(
    minSamplingRate: 1.0,
    maxSamplingRate: 200.0,
    supportsBatching: false,
    supportsCalibration: true,
    additionalCapabilities: {
      'isBuiltIn': true,
      'requiresPermission': false,
    },
  );
  
  @override
  SensorInfo get info => const SensorInfo(
    name: 'Phone Magnetometer',
    manufacturer: 'Device Manufacturer',
    model: 'Built-in',
    additionalInfo: {
      'type': 'MEMS',
      'unit': 'microTesla',
    },
  );
  
  @override
  Future<void> connect() async {
    _status.value = SensorStatus.connected;
  }
  
  @override
  Future<void> disconnect() async {
    await stopDataCollection();
    _status.value = SensorStatus.disconnected;
  }
  
  @override
  Future<void> startDataCollection() async {
    if (_status.value != SensorStatus.connected) {
      throw StateError('Sensor must be connected before starting data collection');
    }
    
    _sensorSubscription = magnetometerEvents.listen(
      (MagnetometerEvent event) {
        final data = MagnetometerData(
          timestamp: DateTime.now(),
          x: event.x,
          y: event.y,
          z: event.z,
        );
        _dataController.add(data);
      },
      onError: (error) {
        debugPrint('Magnetometer stream error: $error');
        _status.value = SensorStatus.error;
      },
    );
    
    _status.value = SensorStatus.collecting;
  }
  
  @override
  Future<void> stopDataCollection() async {
    await _sensorSubscription?.cancel();
    _sensorSubscription = null;
    
    if (_status.value == SensorStatus.collecting) {
      _status.value = SensorStatus.connected;
    }
  }
  
  @override
  Stream<MagnetometerData> get dataStream => _dataController.stream;
  
  @override
  Future<void> configure(SensorConfiguration config) async {
    _configuration = config;
    debugPrint('Phone magnetometer configured (sampling rate is device-dependent)');
  }
  
  @override
  SensorConfiguration get currentConfiguration => _configuration;
  
  @override
  Future<CalibrationResult> calibrate() async {
    // Magnetometer calibration typically involves rotating the device
    return const CalibrationResult(
      success: true,
      calibrationData: {
        'method': 'figure-8',
        'instructions': 'Rotate device in figure-8 pattern for calibration',
      },
    );
  }
  
  @override
  Future<bool> isAvailable() async {
    try {
      await magnetometerEvents.first
          .timeout(const Duration(seconds: 2));
      return true;
    } catch (e) {
      return false;
    }
  }
  
  void dispose() {
    _sensorSubscription?.cancel();
    _dataController.close();
    _status.dispose();
  }
}