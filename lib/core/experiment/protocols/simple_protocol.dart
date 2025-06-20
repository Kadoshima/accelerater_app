import 'dart:async';
import '../interfaces/protocol_interface.dart';
import '../models/protocol_models.dart';
import '../../plugins/research_plugin.dart';

/// Simple configurable experiment protocol
class SimpleProtocol implements IExperimentProtocol {
  @override
  final String id;
  
  @override
  final String name;
  
  @override
  final String description;
  
  @override
  final String version;
  
  @override
  final List<SensorType> requiredSensors;
  
  @override
  final List<IProtocolPhase> phases;
  
  ProtocolState _state = ProtocolState.idle;
  final StreamController<ProtocolState> _stateController = 
      StreamController<ProtocolState>.broadcast();
  final StreamController<ProtocolEvent> _eventController = 
      StreamController<ProtocolEvent>.broadcast();
  
  SimpleProtocol({
    required this.id,
    required this.name,
    required this.description,
    this.version = '1.0.0',
    required this.requiredSensors,
    required this.phases,
  });
  
  /// Create from template
  factory SimpleProtocol.fromTemplate(ProtocolTemplate template) {
    return SimpleProtocol(
      id: template.id,
      name: template.name,
      description: template.description,
      requiredSensors: template.requiredSensors,
      phases: template.phases,
    );
  }
  
  /// Create a simple timed measurement protocol
  factory SimpleProtocol.timedMeasurement({
    required String name,
    required Duration duration,
    required List<SensorType> sensors,
    String? instruction,
  }) {
    final template = CommonProtocolTemplates.timedMeasurement(
      name: name,
      measurementDuration: duration,
      sensors: sensors,
      instruction: instruction,
    );
    return SimpleProtocol.fromTemplate(template);
  }
  
  /// Create an interval training protocol
  factory SimpleProtocol.intervalTraining({
    required String name,
    required int intervals,
    required Duration workDuration,
    required Duration restDuration,
    required List<SensorType> sensors,
  }) {
    final template = CommonProtocolTemplates.intervalTraining(
      name: name,
      intervals: intervals,
      workDuration: workDuration,
      restDuration: restDuration,
      sensors: sensors,
    );
    return SimpleProtocol.fromTemplate(template);
  }
  
  @override
  Future<void> initialize() async {
    _setState(ProtocolState.initializing);
    
    // Perform any necessary initialization
    await Future.delayed(const Duration(milliseconds: 500));
    
    _setState(ProtocolState.ready);
  }
  
  @override
  ValidationResult validate() {
    final errors = <String>[];
    final warnings = <String>[];
    
    // Check if phases are defined
    if (phases.isEmpty) {
      errors.add('No phases defined in protocol');
    }
    
    // Check if required sensors are specified
    if (requiredSensors.isEmpty) {
      warnings.add('No required sensors specified');
    }
    
    // Validate each phase
    for (int i = 0; i < phases.length; i++) {
      final phase = phases[i];
      
      // Check phase has actions or duration
      if (phase.actions.isEmpty && phase.duration == null) {
        errors.add('Phase ${phase.name} has no actions or duration');
      }
      
      // Check transition conditions
      if (phase.transitionConditions.isEmpty && phase.duration == null) {
        warnings.add('Phase ${phase.name} has no transition conditions or duration');
      }
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
  
  @override
  Future<void> start() async {
    if (_state != ProtocolState.ready) {
      throw StateError('Protocol must be initialized before starting');
    }
    
    _setState(ProtocolState.running);
    _emitEvent('protocol_started');
  }
  
  @override
  Future<void> pause() async {
    if (_state != ProtocolState.running) {
      throw StateError('Can only pause a running protocol');
    }
    
    _setState(ProtocolState.paused);
    _emitEvent('protocol_paused');
  }
  
  @override
  Future<void> resume() async {
    if (_state != ProtocolState.paused) {
      throw StateError('Can only resume a paused protocol');
    }
    
    _setState(ProtocolState.running);
    _emitEvent('protocol_resumed');
  }
  
  @override
  Future<void> stop() async {
    if (_state == ProtocolState.idle || _state == ProtocolState.completed) {
      return;
    }
    
    _setState(ProtocolState.idle);
    _emitEvent('protocol_stopped');
  }
  
  @override
  IProtocolPhase? get currentPhase {
    // This should be managed by the protocol engine
    return null;
  }
  
  @override
  ProtocolState get state => _state;
  
  @override
  Stream<ProtocolState> get stateStream => _stateController.stream;
  
  @override
  Stream<ProtocolEvent> get eventStream => _eventController.stream;
  
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'version': version,
    'requiredSensors': requiredSensors.map((s) => s.name).toList(),
    'phases': phases.map((p) => (p as ProtocolPhase).toJson()).toList(),
  };
  
  factory SimpleProtocol.fromJson(Map<String, dynamic> json) {
    return SimpleProtocol(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      version: json['version'] ?? '1.0.0',
      requiredSensors: (json['requiredSensors'] as List?)
          ?.map((s) => SensorType.values.firstWhere((t) => t.name == s))
          .toList() ?? [],
      phases: (json['phases'] as List?)
          ?.map((p) => ProtocolPhase.fromJson(p))
          .toList() ?? [],
    );
  }
  
  void _setState(ProtocolState newState) {
    _state = newState;
    _stateController.add(newState);
  }
  
  void _emitEvent(String type, {Map<String, dynamic>? data}) {
    _eventController.add(ProtocolEvent(
      type: type,
      timestamp: DateTime.now(),
      data: data,
    ));
  }
  
  void dispose() {
    _stateController.close();
    _eventController.close();
  }
}