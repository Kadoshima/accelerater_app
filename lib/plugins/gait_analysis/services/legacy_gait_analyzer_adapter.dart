import 'dart:async';
import '../domain/interfaces/gait_analyzer.dart';
import '../data/models/sensor_data_adapter.dart';
import '../../../utils/gait_analysis_service.dart' as legacy;
import '../../../models/sensor_data.dart' as legacy_models;

/// Adapter to wrap the legacy GaitAnalysisService with the new interface
class LegacyGaitAnalyzerAdapter implements IGaitAnalyzer {
  final legacy.GaitAnalysisService _legacyService;
  final StreamController<StepEvent> _stepEventController = StreamController<StepEvent>.broadcast();
  StreamSubscription? _legacyStepSubscription;
  
  LegacyGaitAnalyzerAdapter({
    GaitAnalysisConfig? config,
  }) : _legacyService = legacy.GaitAnalysisService(
    totalDataSeconds: config?.totalDataSeconds ?? 20,
    windowSizeSeconds: config?.windowSizeSeconds ?? 10,
    slideIntervalSeconds: config?.slideIntervalSeconds ?? 1,
    minFrequency: config?.minFrequency ?? 1.0,
    maxFrequency: config?.maxFrequency ?? 3.5,
    minSpm: config?.minSpm ?? 60.0,
    maxSpm: config?.maxSpm ?? 160.0,
    smoothingFactor: config?.smoothingFactor ?? 0.3,
    minReliability: config?.minReliability ?? 0.25,
    staticThreshold: config?.staticThreshold ?? 0.02,
    useSingleAxisOnly: config?.useSingleAxisOnly ?? false,
    verticalAxis: config?.verticalAxis ?? 'x',
  ) {
    // Subscribe to legacy step stream and convert to new format
    _legacyStepSubscription = _legacyService.stepStream.listen((stepCount) {
      _stepEventController.add(StepEvent(
        timestamp: DateTime.now(),
        stepNumber: stepCount,
        instantaneousSpm: _legacyService.currentSpm,
      ));
    });
  }
  
  @override
  double get currentSpm => _legacyService.currentSpm;
  
  @override
  double get reliability => _legacyService.reliability;
  
  @override
  int get stepCount => _legacyService.stepCount;
  
  @override
  Stream<StepEvent> get stepStream => _stepEventController.stream;
  
  @override
  List<int> getLatestStepIntervals({int count = 10}) {
    return _legacyService.getLatestStepIntervals(count: count);
  }
  
  @override
  void processSensorData(GaitSensorData data) {
    // Convert GaitSensorData to legacy M5SensorData
    final legacyData = legacy_models.M5SensorData(
      accelerometerX: data.accelerationX ?? 0.0,
      accelerometerY: data.accelerationY ?? 0.0,
      accelerometerZ: data.accelerationZ ?? 0.0,
      gyroscopeX: 0.0,
      gyroscopeY: 0.0,
      gyroscopeZ: 0.0,
      magnetometerX: 0.0,
      magnetometerY: 0.0,
      magnetometerZ: 0.0,
      timestamp: data.timestamp.millisecondsSinceEpoch,
    );
    
    _legacyService.addSensorData(legacyData);
  }
  
  @override
  void reset() {
    _legacyService.reset();
  }
  
  @override
  void dispose() {
    _legacyStepSubscription?.cancel();
    _stepEventController.close();
  }
  
  /// Access to legacy service for debugging
  legacy.GaitAnalysisService get legacyService => _legacyService;
}