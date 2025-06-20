import 'dart:async';
import '../../../core/plugins/research_plugin.dart';
import '../../../core/sensors/models/sensor_data_models.dart';
import '../domain/interfaces/gait_analyzer.dart';
import '../data/models/sensor_data_adapter.dart';
import 'legacy_gait_analyzer_adapter.dart';

/// Processes sensor data for gait analysis
class GaitDataProcessor extends DataProcessor {
  final Map<String, dynamic> _configuration;
  late final IGaitAnalyzer _gaitAnalyzer;
  final StreamController<ProcessedData> _processedDataController = 
      StreamController<ProcessedData>.broadcast();
  
  GaitDataProcessor({
    required Map<String, dynamic> settings,
  }) : _configuration = Map<String, dynamic>.from(settings) {
    // Create gait analyzer with configuration
    final config = GaitAnalysisConfig(
      totalDataSeconds: _configuration['totalDataSeconds'] ?? 20,
      windowSizeSeconds: _configuration['windowSizeSeconds'] ?? 10,
      slideIntervalSeconds: _configuration['slideIntervalSeconds'] ?? 1,
      minFrequency: _configuration['minFrequency'] ?? 1.0,
      maxFrequency: _configuration['maxFrequency'] ?? 3.5,
      minSpm: (_configuration['minSpm'] ?? 60.0).toDouble(),
      maxSpm: (_configuration['maxSpm'] ?? 160.0).toDouble(),
      smoothingFactor: _configuration['smoothingFactor'] ?? 0.3,
      minReliability: _configuration['minReliability'] ?? 0.25,
      staticThreshold: _configuration['staticThreshold'] ?? 0.02,
      useSingleAxisOnly: _configuration['useSingleAxisOnly'] ?? false,
      verticalAxis: _configuration['verticalAxis'] ?? 'x',
    );
    
    _gaitAnalyzer = LegacyGaitAnalyzerAdapter(config: config);
    
    // Subscribe to step events
    _gaitAnalyzer.stepStream.listen((stepEvent) {
      _processedDataController.add(GaitProcessedData(
        timestamp: stepEvent.timestamp,
        data: {
          'type': 'step_detected',
          'stepNumber': stepEvent.stepNumber,
          'instantaneousSpm': stepEvent.instantaneousSpm,
        },
      ));
    });
  }
  
  @override
  Map<String, dynamic> get configuration => Map.unmodifiable(_configuration);
  
  @override
  void updateConfiguration(Map<String, dynamic> config) {
    _configuration.addAll(config);
    // TODO: Update analyzer configuration
  }
  
  @override
  Stream<ProcessedData> process(Stream<SensorData> input) {
    // Process incoming sensor data
    input.listen((data) {
      if (data is AccelerometerData) {
        _processAccelerometerData(data);
      } else if (data is IMUData && data.accelerometer != null) {
        _processIMUData(data);
      }
    });
    
    // Return processed data stream
    return _processedDataController.stream;
  }
  
  void _processAccelerometerData(AccelerometerData data) {
    // Convert to gait sensor data and process
    final gaitData = GaitSensorDataFactory.fromAccelerometerData(data);
    _gaitAnalyzer.processSensorData(gaitData);
    
    // Emit current analysis results
    _emitCurrentResults(data.timestamp);
  }
  
  void _processIMUData(IMUData data) {
    // Convert to gait sensor data and process
    final gaitData = GaitSensorDataFactory.fromIMUData(data);
    _gaitAnalyzer.processSensorData(gaitData);
    
    // Emit current analysis results
    _emitCurrentResults(data.timestamp);
  }
  
  void _emitCurrentResults(DateTime timestamp) {
    _processedDataController.add(GaitProcessedData(
      timestamp: timestamp,
      data: {
        'type': 'gait_analysis',
        'spm': _gaitAnalyzer.currentSpm,
        'confidence': _gaitAnalyzer.reliability,
        'stepCount': _gaitAnalyzer.stepCount,
      },
    ));
  }
  
  void dispose() {
    _gaitAnalyzer.dispose();
    _processedDataController.close();
  }
}

/// Processed data specific to gait analysis
class GaitProcessedData extends ProcessedData {
  GaitProcessedData({
    required DateTime timestamp,
    required Map<String, dynamic> data,
  }) : super(timestamp: timestamp, data: data);
  
  // Convenience getters
  double? get spm => data['spm'] as double?;
  double? get confidence => data['confidence'] as double?;
  double? get cv => data['cv'] as double?;
  String? get phase => data['phase'] as String?;
}