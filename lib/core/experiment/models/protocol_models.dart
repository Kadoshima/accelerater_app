import 'package:flutter/material.dart';
import '../interfaces/protocol_interface.dart';
import '../../plugins/research_plugin.dart';

/// Base implementation of protocol phase
class ProtocolPhase implements IProtocolPhase {
  @override
  final String id;
  
  @override
  final String name;
  
  @override
  final String description;
  
  @override
  final Duration? duration;
  
  @override
  final PhaseType type;
  
  @override
  final List<IProtocolAction> actions;
  
  @override
  final List<ITransitionCondition> transitionConditions;
  
  bool _isComplete = false;
  DateTime? _startTime;
  
  ProtocolPhase({
    required this.id,
    required this.name,
    required this.description,
    this.duration,
    required this.type,
    required this.actions,
    required this.transitionConditions,
  });
  
  @override
  Future<void> execute() async {
    _startTime = DateTime.now();
    _isComplete = false;
    
    // Execute all actions
    for (final action in actions) {
      await action.execute();
    }
    
    // Wait for transition conditions
    while (!_checkTransitionConditions()) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    _isComplete = true;
  }
  
  bool _checkTransitionConditions() {
    if (transitionConditions.isEmpty) {
      // If no conditions, check duration
      if (duration != null && _startTime != null) {
        return DateTime.now().difference(_startTime!) >= duration!;
      }
      return true;
    }
    
    // Check all conditions (AND logic)
    return transitionConditions.every((condition) => condition.isMet());
  }
  
  @override
  bool get isComplete => _isComplete;
  
  @override
  Widget buildUI(BuildContext context) {
    // Default UI - can be overridden
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (duration != null) ...[
            const SizedBox(height: 24),
            Text(
              'Duration: ${duration!.inSeconds} seconds',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
  
  factory ProtocolPhase.fromJson(Map<String, dynamic> json) {
    return ProtocolPhase(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      duration: json['duration'] != null 
          ? Duration(seconds: json['duration']) 
          : null,
      type: PhaseType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PhaseType.custom,
      ),
      actions: (json['actions'] as List?)
          ?.map((a) => ProtocolAction.fromJson(a))
          .toList() ?? [],
      transitionConditions: (json['transitionConditions'] as List?)
          ?.map((c) => TransitionCondition.fromJson(c))
          .toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'duration': duration?.inSeconds,
    'type': type.name,
    'actions': actions.map((a) => (a as ProtocolAction).toJson()).toList(),
    'transitionConditions': transitionConditions
        .map((c) => (c as TransitionCondition).toJson()).toList(),
  };
}

/// Base implementation of protocol action
class ProtocolAction implements IProtocolAction {
  @override
  final String id;
  
  @override
  final ActionType type;
  
  @override
  final Map<String, dynamic> parameters;
  
  final Future<void> Function()? customExecutor;
  
  ProtocolAction({
    required this.id,
    required this.type,
    required this.parameters,
    this.customExecutor,
  });
  
  @override
  Future<void> execute() async {
    switch (type) {
      case ActionType.startSensorCollection:
        // Handled by protocol engine
        break;
      case ActionType.stopSensorCollection:
        // Handled by protocol engine
        break;
      case ActionType.displayInstruction:
        // Handled by protocol engine
        break;
      case ActionType.playAudio:
        // Handled by protocol engine
        break;
      case ActionType.showVisual:
        // Handled by protocol engine
        break;
      case ActionType.recordMarker:
        // Handled by protocol engine
        break;
      case ActionType.sendNotification:
        // Handled by protocol engine
        break;
      case ActionType.executeCustom:
        if (customExecutor != null) {
          await customExecutor!();
        }
        break;
    }
  }
  
  factory ProtocolAction.fromJson(Map<String, dynamic> json) {
    return ProtocolAction(
      id: json['id'],
      type: ActionType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      parameters: json['parameters'] ?? {},
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'parameters': parameters,
  };
}

/// Base implementation of transition condition
class TransitionCondition implements ITransitionCondition {
  @override
  final ConditionType type;
  
  @override
  final Map<String, dynamic> parameters;
  
  final bool Function()? customChecker;
  DateTime? _startTime;
  int _eventCount = 0;
  
  TransitionCondition({
    required this.type,
    required this.parameters,
    this.customChecker,
  });
  
  void initialize() {
    _startTime = DateTime.now();
    _eventCount = 0;
  }
  
  void recordEvent() {
    _eventCount++;
  }
  
  @override
  bool isMet() {
    switch (type) {
      case ConditionType.timeBased:
        if (_startTime == null) return false;
        final duration = Duration(seconds: parameters['durationSeconds'] ?? 0);
        return DateTime.now().difference(_startTime!) >= duration;
        
      case ConditionType.eventCount:
        final targetCount = parameters['count'] ?? 1;
        return _eventCount >= targetCount;
        
      case ConditionType.userInput:
        // Handled by protocol engine
        return parameters['received'] == true;
        
      case ConditionType.dataThreshold:
        // Handled by protocol engine
        return parameters['thresholdMet'] == true;
        
      case ConditionType.custom:
        return customChecker?.call() ?? false;
    }
  }
  
  factory TransitionCondition.fromJson(Map<String, dynamic> json) {
    return TransitionCondition(
      type: ConditionType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      parameters: json['parameters'] ?? {},
    );
  }
  
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'parameters': parameters,
  };
}

/// Protocol template for common experiment patterns
class ProtocolTemplate {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<IProtocolPhase> phases;
  final List<SensorType> requiredSensors;
  final Map<String, dynamic> defaultParameters;
  
  const ProtocolTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.phases,
    required this.requiredSensors,
    this.defaultParameters = const {},
  });
}

/// Common protocol templates
class CommonProtocolTemplates {
  /// Simple timed measurement protocol
  static ProtocolTemplate timedMeasurement({
    required String name,
    required Duration measurementDuration,
    required List<SensorType> sensors,
    String? instruction,
  }) {
    return ProtocolTemplate(
      id: 'timed_measurement_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: 'Simple timed measurement protocol',
      category: 'basic',
      requiredSensors: sensors,
      phases: [
        if (instruction != null)
          ProtocolPhase(
            id: 'instruction',
            name: 'Instructions',
            description: instruction,
            duration: const Duration(seconds: 10),
            type: PhaseType.preparation,
            actions: [
              ProtocolAction(
                id: 'show_instruction',
                type: ActionType.displayInstruction,
                parameters: {'text': instruction},
              ),
            ],
            transitionConditions: [
              TransitionCondition(
                type: ConditionType.userInput,
                parameters: {'waitForConfirmation': true},
              ),
            ],
          ),
        ProtocolPhase(
          id: 'measurement',
          name: 'Measurement',
          description: 'Data collection phase',
          duration: measurementDuration,
          type: PhaseType.measurement,
          actions: [
            ProtocolAction(
              id: 'start_sensors',
              type: ActionType.startSensorCollection,
              parameters: {'sensors': sensors.map((s) => s.name).toList()},
            ),
            ProtocolAction(
              id: 'start_marker',
              type: ActionType.recordMarker,
              parameters: {'marker': 'measurement_start'},
            ),
          ],
          transitionConditions: [
            TransitionCondition(
              type: ConditionType.timeBased,
              parameters: {'durationSeconds': measurementDuration.inSeconds},
            ),
          ],
        ),
      ],
    );
  }
  
  /// Interval training protocol
  static ProtocolTemplate intervalTraining({
    required String name,
    required int intervals,
    required Duration workDuration,
    required Duration restDuration,
    required List<SensorType> sensors,
  }) {
    final phases = <IProtocolPhase>[];
    
    // Add preparation phase
    phases.add(ProtocolPhase(
      id: 'preparation',
      name: 'Preparation',
      description: 'Get ready for interval training',
      duration: const Duration(seconds: 10),
      type: PhaseType.preparation,
      actions: [
        ProtocolAction(
          id: 'prep_instruction',
          type: ActionType.displayInstruction,
          parameters: {
            'text': 'Interval training: $intervals intervals of ${workDuration.inSeconds}s work / ${restDuration.inSeconds}s rest'
          },
        ),
      ],
      transitionConditions: [],
    ));
    
    // Add work/rest intervals
    for (int i = 0; i < intervals; i++) {
      // Work phase
      phases.add(ProtocolPhase(
        id: 'work_$i',
        name: 'Work Interval ${i + 1}',
        description: 'Perform activity',
        duration: workDuration,
        type: PhaseType.measurement,
        actions: [
          if (i == 0)
            ProtocolAction(
              id: 'start_sensors',
              type: ActionType.startSensorCollection,
              parameters: {'sensors': sensors.map((s) => s.name).toList()},
            ),
          ProtocolAction(
            id: 'work_start_$i',
            type: ActionType.recordMarker,
            parameters: {'marker': 'work_start', 'interval': i + 1},
          ),
          ProtocolAction(
            id: 'work_notification_$i',
            type: ActionType.sendNotification,
            parameters: {'message': 'Start work interval ${i + 1}'},
          ),
        ],
        transitionConditions: [],
      ));
      
      // Rest phase (except after last interval)
      if (i < intervals - 1) {
        phases.add(ProtocolPhase(
          id: 'rest_$i',
          name: 'Rest Interval ${i + 1}',
          description: 'Rest',
          duration: restDuration,
          type: PhaseType.rest,
          actions: [
            ProtocolAction(
              id: 'rest_start_$i',
              type: ActionType.recordMarker,
              parameters: {'marker': 'rest_start', 'interval': i + 1},
            ),
            ProtocolAction(
              id: 'rest_notification_$i',
              type: ActionType.sendNotification,
              parameters: {'message': 'Rest interval ${i + 1}'},
            ),
          ],
          transitionConditions: [],
        ));
      }
    }
    
    // Add completion phase
    phases.add(ProtocolPhase(
      id: 'completion',
      name: 'Complete',
      description: 'Training complete!',
      duration: const Duration(seconds: 5),
      type: PhaseType.preparation,
      actions: [
        ProtocolAction(
          id: 'stop_sensors',
          type: ActionType.stopSensorCollection,
          parameters: {},
        ),
        ProtocolAction(
          id: 'complete_marker',
          type: ActionType.recordMarker,
          parameters: {'marker': 'training_complete'},
        ),
      ],
      transitionConditions: [],
    ));
    
    return ProtocolTemplate(
      id: 'interval_training_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: 'Interval training protocol',
      category: 'training',
      requiredSensors: sensors,
      phases: phases,
      defaultParameters: {
        'intervals': intervals,
        'workDuration': workDuration.inSeconds,
        'restDuration': restDuration.inSeconds,
      },
    );
  }
}