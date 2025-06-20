import 'package:flutter/material.dart';

/// Base interface for all research plugins
abstract class ResearchPlugin {
  /// Unique identifier for the plugin
  String get id;
  
  /// Human-readable name of the research
  String get name;
  
  /// Description of the research
  String get description;
  
  /// Version of the plugin
  String get version;
  
  /// Required sensor types for this research
  List<SensorType> get requiredSensors;
  
  /// Optional sensor types that enhance the research
  List<SensorType> get optionalSensors => [];
  
  /// Initialize the plugin
  Future<void> initialize();
  
  /// Clean up resources
  Future<void> dispose();
  
  /// Build the configuration screen for the research
  Widget buildConfigScreen(BuildContext context);
  
  /// Build the main experiment screen
  Widget buildExperimentScreen(BuildContext context);
  
  /// Create data processor for this research
  DataProcessor createDataProcessor();
  
  /// Export research-specific settings
  Map<String, dynamic> exportSettings();
  
  /// Import research-specific settings
  void importSettings(Map<String, dynamic> settings);
  
  /// Validate if the plugin can run with current setup
  ValidationResult validate();
}

/// Types of sensors that can be used
enum SensorType {
  accelerometer,
  gyroscope,
  magnetometer,
  heartRate,
  gps,
  barometer,
  temperature,
  proximity,
  light,
  microphone,
}

/// Base interface for data processing
abstract class DataProcessor {
  /// Process incoming sensor data
  Stream<ProcessedData> process(Stream<SensorData> input);
  
  /// Get current processing configuration
  Map<String, dynamic> get configuration;
  
  /// Update processing configuration
  void updateConfiguration(Map<String, dynamic> config);
}

/// Base class for sensor data
abstract class SensorData {
  final DateTime timestamp;
  final SensorType type;
  
  const SensorData({
    required this.timestamp,
    required this.type,
  });
}

/// Base class for processed data
abstract class ProcessedData {
  final DateTime timestamp;
  final Map<String, dynamic> data;
  
  const ProcessedData({
    required this.timestamp,
    required this.data,
  });
}

/// Validation result for plugin readiness
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  
  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
  
  factory ValidationResult.valid() => const ValidationResult(isValid: true);
  
  factory ValidationResult.invalid(List<String> errors) => ValidationResult(
    isValid: false,
    errors: errors,
  );
}