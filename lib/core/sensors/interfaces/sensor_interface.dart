import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/plugins/research_plugin.dart';

/// Base interface for all sensors
abstract class ISensor<T extends SensorData> {
  /// Unique identifier for the sensor instance
  String get id;
  
  /// Type of sensor
  SensorType get type;
  
  /// Current connection status
  ValueNotifier<SensorStatus> get status;
  
  /// Sensor capabilities and specifications
  SensorCapabilities get capabilities;
  
  /// Connect to the sensor
  Future<void> connect();
  
  /// Disconnect from the sensor
  Future<void> disconnect();
  
  /// Start data collection
  Future<void> startDataCollection();
  
  /// Stop data collection
  Future<void> stopDataCollection();
  
  /// Stream of sensor data
  Stream<T> get dataStream;
  
  /// Configure sensor settings
  Future<void> configure(SensorConfiguration config);
  
  /// Get current configuration
  SensorConfiguration get currentConfiguration;
  
  /// Calibrate the sensor
  Future<CalibrationResult> calibrate();
  
  /// Check if sensor is available on this device
  Future<bool> isAvailable();
  
  /// Get sensor information
  SensorInfo get info;
}

/// Sensor connection status
enum SensorStatus {
  disconnected,
  connecting,
  connected,
  collecting,
  error,
}

/// Sensor capabilities
class SensorCapabilities {
  final double minSamplingRate;
  final double maxSamplingRate;
  final List<double> availableSamplingRates;
  final bool supportsBatching;
  final bool supportsCalibration;
  final Map<String, dynamic> additionalCapabilities;
  
  const SensorCapabilities({
    required this.minSamplingRate,
    required this.maxSamplingRate,
    this.availableSamplingRates = const [],
    this.supportsBatching = false,
    this.supportsCalibration = false,
    this.additionalCapabilities = const {},
  });
}

/// Sensor configuration
class SensorConfiguration {
  final double samplingRate;
  final bool enableBatching;
  final int batchSize;
  final Map<String, dynamic> additionalSettings;
  
  const SensorConfiguration({
    required this.samplingRate,
    this.enableBatching = false,
    this.batchSize = 1,
    this.additionalSettings = const {},
  });
  
  SensorConfiguration copyWith({
    double? samplingRate,
    bool? enableBatching,
    int? batchSize,
    Map<String, dynamic>? additionalSettings,
  }) {
    return SensorConfiguration(
      samplingRate: samplingRate ?? this.samplingRate,
      enableBatching: enableBatching ?? this.enableBatching,
      batchSize: batchSize ?? this.batchSize,
      additionalSettings: additionalSettings ?? this.additionalSettings,
    );
  }
}

/// Sensor information
class SensorInfo {
  final String name;
  final String manufacturer;
  final String model;
  final String version;
  final Map<String, dynamic> additionalInfo;
  
  const SensorInfo({
    required this.name,
    this.manufacturer = 'Unknown',
    this.model = 'Unknown',
    this.version = 'Unknown',
    this.additionalInfo = const {},
  });
}

/// Calibration result
class CalibrationResult {
  final bool success;
  final Map<String, dynamic> calibrationData;
  final String? errorMessage;
  
  const CalibrationResult({
    required this.success,
    this.calibrationData = const {},
    this.errorMessage,
  });
}

/// Manager for multiple sensors
abstract class ISensorManager {
  /// Register a sensor
  void registerSensor(ISensor sensor);
  
  /// Unregister a sensor
  void unregisterSensor(String sensorId);
  
  /// Get sensor by ID
  ISensor? getSensor(String sensorId);
  
  /// Get all sensors of a specific type
  List<ISensor> getSensorsByType(SensorType type);
  
  /// Get all registered sensors
  List<ISensor> get allSensors;
  
  /// Connect all sensors
  Future<void> connectAll();
  
  /// Disconnect all sensors
  Future<void> disconnectAll();
  
  /// Start data collection for all sensors
  Future<void> startAllDataCollection();
  
  /// Stop data collection for all sensors
  Future<void> stopAllDataCollection();
  
  /// Combined data stream from all sensors
  Stream<SensorData> get combinedDataStream;
  
  /// Dispose of all resources
  Future<void> dispose();
}