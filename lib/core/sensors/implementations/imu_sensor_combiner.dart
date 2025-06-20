import 'dart:async';
import 'package:flutter/foundation.dart';
import '../interfaces/sensor_interface.dart';
import '../models/sensor_data_models.dart';
import '../../plugins/research_plugin.dart';

/// Combines multiple sensor streams into IMU data
class IMUSensorCombiner extends ISensor<IMUData> {
  final ISensor<AccelerometerData>? accelerometerSensor;
  final ISensor<GyroscopeData>? gyroscopeSensor;
  final ISensor<MagnetometerData>? magnetometerSensor;
  
  final String _id;
  final ValueNotifier<SensorStatus> _status = ValueNotifier(SensorStatus.disconnected);
  final StreamController<IMUData> _dataController = StreamController<IMUData>.broadcast();
  
  // Latest values from each sensor
  AccelerometerData? _latestAccelerometer;
  GyroscopeData? _latestGyroscope;
  MagnetometerData? _latestMagnetometer;
  
  // Subscriptions
  StreamSubscription? _accelSubscription;
  StreamSubscription? _gyroSubscription;
  StreamSubscription? _magSubscription;
  
  // Timer for data emission
  Timer? _emissionTimer;
  
  SensorConfiguration _configuration;
  
  IMUSensorCombiner({
    this.accelerometerSensor,
    this.gyroscopeSensor,
    this.magnetometerSensor,
    String? id,
    SensorConfiguration? initialConfig,
  }) : _id = id ?? 'imu_combined',
       _configuration = initialConfig ?? const SensorConfiguration(samplingRate: 100.0) {
    if (accelerometerSensor == null && gyroscopeSensor == null && magnetometerSensor == null) {
      throw ArgumentError('At least one sensor must be provided');
    }
  }
  
  @override
  String get id => _id;
  
  @override
  SensorType get type => SensorType.accelerometer; // Primary type
  
  @override
  ValueNotifier<SensorStatus> get status => _status;
  
  @override
  SensorCapabilities get capabilities {
    // Find minimum and maximum sampling rates from all sensors
    double minRate = double.infinity;
    double maxRate = 0.0;
    
    for (final sensor in [accelerometerSensor, gyroscopeSensor, magnetometerSensor]) {
      if (sensor != null) {
        minRate = minRate.clamp(sensor.capabilities.minSamplingRate, minRate);
        maxRate = maxRate.clamp(maxRate, sensor.capabilities.maxSamplingRate);
      }
    }
    
    return SensorCapabilities(
      minSamplingRate: minRate,
      maxSamplingRate: maxRate,
      supportsBatching: false,
      supportsCalibration: false,
      additionalCapabilities: {
        'isCombined': true,
        'hasAccelerometer': accelerometerSensor != null,
        'hasGyroscope': gyroscopeSensor != null,
        'hasMagnetometer': magnetometerSensor != null,
      },
    );
  }
  
  @override
  SensorInfo get info => SensorInfo(
    name: 'Combined IMU',
    manufacturer: 'Virtual',
    model: 'Combined',
    additionalInfo: {
      'sensors': [
        if (accelerometerSensor != null) 'accelerometer',
        if (gyroscopeSensor != null) 'gyroscope',
        if (magnetometerSensor != null) 'magnetometer',
      ],
    },
  );
  
  @override
  Future<void> connect() async {
    _status.value = SensorStatus.connecting;
    
    final futures = <Future>[];
    if (accelerometerSensor != null) futures.add(accelerometerSensor!.connect());
    if (gyroscopeSensor != null) futures.add(gyroscopeSensor!.connect());
    if (magnetometerSensor != null) futures.add(magnetometerSensor!.connect());
    
    try {
      await Future.wait(futures);
      _status.value = SensorStatus.connected;
    } catch (e) {
      _status.value = SensorStatus.error;
      rethrow;
    }
  }
  
  @override
  Future<void> disconnect() async {
    await stopDataCollection();
    
    final futures = <Future>[];
    if (accelerometerSensor != null) futures.add(accelerometerSensor!.disconnect());
    if (gyroscopeSensor != null) futures.add(gyroscopeSensor!.disconnect());
    if (magnetometerSensor != null) futures.add(magnetometerSensor!.disconnect());
    
    await Future.wait(futures);
    _status.value = SensorStatus.disconnected;
  }
  
  @override
  Future<void> startDataCollection() async {
    if (_status.value != SensorStatus.connected) {
      throw StateError('Sensor must be connected before starting data collection');
    }
    
    // Start individual sensors
    final futures = <Future>[];
    if (accelerometerSensor != null) futures.add(accelerometerSensor!.startDataCollection());
    if (gyroscopeSensor != null) futures.add(gyroscopeSensor!.startDataCollection());
    if (magnetometerSensor != null) futures.add(magnetometerSensor!.startDataCollection());
    
    await Future.wait(futures);
    
    // Subscribe to sensor streams
    _accelSubscription = accelerometerSensor?.dataStream.listen((data) {
      _latestAccelerometer = data;
      _maybeEmitCombinedData();
    });
    
    _gyroSubscription = gyroscopeSensor?.dataStream.listen((data) {
      _latestGyroscope = data;
      _maybeEmitCombinedData();
    });
    
    _magSubscription = magnetometerSensor?.dataStream.listen((data) {
      _latestMagnetometer = data;
      _maybeEmitCombinedData();
    });
    
    // Set up emission timer based on sampling rate
    final period = Duration(milliseconds: (1000 / _configuration.samplingRate).round());
    _emissionTimer = Timer.periodic(period, (_) => _emitCombinedData());
    
    _status.value = SensorStatus.collecting;
  }
  
  @override
  Future<void> stopDataCollection() async {
    _emissionTimer?.cancel();
    _emissionTimer = null;
    
    await _accelSubscription?.cancel();
    await _gyroSubscription?.cancel();
    await _magSubscription?.cancel();
    
    _accelSubscription = null;
    _gyroSubscription = null;
    _magSubscription = null;
    
    // Stop individual sensors
    final futures = <Future>[];
    if (accelerometerSensor != null) futures.add(accelerometerSensor!.stopDataCollection());
    if (gyroscopeSensor != null) futures.add(gyroscopeSensor!.stopDataCollection());
    if (magnetometerSensor != null) futures.add(magnetometerSensor!.stopDataCollection());
    
    await Future.wait(futures);
    
    if (_status.value == SensorStatus.collecting) {
      _status.value = SensorStatus.connected;
    }
  }
  
  @override
  Stream<IMUData> get dataStream => _dataController.stream;
  
  @override
  Future<void> configure(SensorConfiguration config) async {
    _configuration = config;
    
    // Configure individual sensors
    final futures = <Future>[];
    if (accelerometerSensor != null) futures.add(accelerometerSensor!.configure(config));
    if (gyroscopeSensor != null) futures.add(gyroscopeSensor!.configure(config));
    if (magnetometerSensor != null) futures.add(magnetometerSensor!.configure(config));
    
    await Future.wait(futures);
    
    // Restart timer if collecting
    if (_status.value == SensorStatus.collecting) {
      _emissionTimer?.cancel();
      final period = Duration(milliseconds: (1000 / _configuration.samplingRate).round());
      _emissionTimer = Timer.periodic(period, (_) => _emitCombinedData());
    }
  }
  
  @override
  SensorConfiguration get currentConfiguration => _configuration;
  
  @override
  Future<CalibrationResult> calibrate() async {
    // Calibrate all available sensors
    final results = <String, CalibrationResult>{};
    
    if (accelerometerSensor != null) {
      results['accelerometer'] = await accelerometerSensor!.calibrate();
    }
    if (gyroscopeSensor != null) {
      results['gyroscope'] = await gyroscopeSensor!.calibrate();
    }
    if (magnetometerSensor != null) {
      results['magnetometer'] = await magnetometerSensor!.calibrate();
    }
    
    // Check if all calibrations succeeded
    final allSuccess = results.values.every((result) => result.success);
    
    return CalibrationResult(
      success: allSuccess,
      calibrationData: {
        'results': results.map((key, value) => MapEntry(key, {
          'success': value.success,
          'error': value.errorMessage,
          'data': value.calibrationData,
        })),
      },
      errorMessage: allSuccess ? null : 'Some sensors failed calibration',
    );
  }
  
  @override
  Future<bool> isAvailable() async {
    // Check if at least one sensor is available
    final checks = <Future<bool>>[];
    
    if (accelerometerSensor != null) checks.add(accelerometerSensor!.isAvailable());
    if (gyroscopeSensor != null) checks.add(gyroscopeSensor!.isAvailable());
    if (magnetometerSensor != null) checks.add(magnetometerSensor!.isAvailable());
    
    final results = await Future.wait(checks);
    return results.any((available) => available);
  }
  
  /// Maybe emit combined data if synchronization is tight
  void _maybeEmitCombinedData() {
    if (_configuration.additionalSettings['syncEmission'] == true) {
      _emitCombinedData();
    }
  }
  
  /// Emit combined IMU data
  void _emitCombinedData() {
    // Only emit if we have at least one data point
    if (_latestAccelerometer == null && 
        _latestGyroscope == null && 
        _latestMagnetometer == null) {
      return;
    }
    
    final now = DateTime.now();
    
    // Create IMU data with latest values
    final imuData = IMUData(
      timestamp: now,
      accelerometer: _latestAccelerometer,
      gyroscope: _latestGyroscope,
      magnetometer: _latestMagnetometer,
    );
    
    _dataController.add(imuData);
  }
  
  void dispose() {
    _emissionTimer?.cancel();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _magSubscription?.cancel();
    _dataController.close();
    _status.dispose();
  }
}