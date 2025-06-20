import 'dart:async';

/// Interface for gait analysis algorithms
abstract class IGaitAnalyzer {
  /// Current steps per minute
  double get currentSpm;
  
  /// Reliability of the current SPM detection (0.0-1.0)
  double get reliability;
  
  /// Total step count
  int get stepCount;
  
  /// Stream of step events
  Stream<StepEvent> get stepStream;
  
  /// Get latest step intervals
  List<int> getLatestStepIntervals({int count = 10});
  
  /// Process new sensor data
  void processSensorData(GaitSensorData data);
  
  /// Reset the analyzer
  void reset();
  
  /// Dispose resources
  void dispose();
}

/// Step event data
class StepEvent {
  final DateTime timestamp;
  final int stepNumber;
  final double? instantaneousSpm;
  
  const StepEvent({
    required this.timestamp,
    required this.stepNumber,
    this.instantaneousSpm,
  });
}

/// Sensor data specific to gait analysis
abstract class GaitSensorData {
  double? get accelerationX;
  double? get accelerationY;
  double? get accelerationZ;
  double? get magnitude;
  DateTime get timestamp;
}

/// Configuration for gait analysis
class GaitAnalysisConfig {
  final int totalDataSeconds;
  final int windowSizeSeconds;
  final int slideIntervalSeconds;
  final double minFrequency;
  final double maxFrequency;
  final double minSpm;
  final double maxSpm;
  final double smoothingFactor;
  final double minReliability;
  final double staticThreshold;
  final bool useSingleAxisOnly;
  final String verticalAxis;
  final double correctionFactor;
  
  const GaitAnalysisConfig({
    this.totalDataSeconds = 20,
    this.windowSizeSeconds = 10,
    this.slideIntervalSeconds = 1,
    this.minFrequency = 1.0,
    this.maxFrequency = 3.5,
    this.minSpm = 60.0,
    this.maxSpm = 160.0,
    this.smoothingFactor = 0.3,
    this.minReliability = 0.25,
    this.staticThreshold = 0.02,
    this.useSingleAxisOnly = false,
    this.verticalAxis = 'x',
    this.correctionFactor = 1.07,
  });
  
  GaitAnalysisConfig copyWith({
    int? totalDataSeconds,
    int? windowSizeSeconds,
    int? slideIntervalSeconds,
    double? minFrequency,
    double? maxFrequency,
    double? minSpm,
    double? maxSpm,
    double? smoothingFactor,
    double? minReliability,
    double? staticThreshold,
    bool? useSingleAxisOnly,
    String? verticalAxis,
    double? correctionFactor,
  }) {
    return GaitAnalysisConfig(
      totalDataSeconds: totalDataSeconds ?? this.totalDataSeconds,
      windowSizeSeconds: windowSizeSeconds ?? this.windowSizeSeconds,
      slideIntervalSeconds: slideIntervalSeconds ?? this.slideIntervalSeconds,
      minFrequency: minFrequency ?? this.minFrequency,
      maxFrequency: maxFrequency ?? this.maxFrequency,
      minSpm: minSpm ?? this.minSpm,
      maxSpm: maxSpm ?? this.maxSpm,
      smoothingFactor: smoothingFactor ?? this.smoothingFactor,
      minReliability: minReliability ?? this.minReliability,
      staticThreshold: staticThreshold ?? this.staticThreshold,
      useSingleAxisOnly: useSingleAxisOnly ?? this.useSingleAxisOnly,
      verticalAxis: verticalAxis ?? this.verticalAxis,
      correctionFactor: correctionFactor ?? this.correctionFactor,
    );
  }
}