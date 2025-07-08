import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../plugins/research_plugin.dart';

/// Base interface for experiment protocols
abstract class IExperimentProtocol {
  /// Unique identifier for the protocol
  String get id;
  
  /// Protocol name
  String get name;
  
  /// Protocol description
  String get description;
  
  /// Protocol version
  String get version;
  
  /// Required sensors for this protocol
  List<SensorType> get requiredSensors;
  
  /// Protocol phases/stages
  List<IProtocolPhase> get phases;
  
  /// Initialize the protocol
  Future<void> initialize();
  
  /// Validate protocol configuration
  ValidationResult validate();
  
  /// Start the protocol execution
  Future<void> start();
  
  /// Pause the protocol
  Future<void> pause();
  
  /// Resume the protocol
  Future<void> resume();
  
  /// Stop the protocol
  Future<void> stop();
  
  /// Get current phase
  IProtocolPhase? get currentPhase;
  
  /// Get protocol state
  ProtocolState get state;
  
  /// Protocol state changes stream
  Stream<ProtocolState> get stateStream;
  
  /// Protocol events stream
  Stream<ProtocolEvent> get eventStream;
  
  /// Export protocol configuration
  Map<String, dynamic> toJson();
  
  /// Import protocol configuration
  factory IExperimentProtocol.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError('Factory constructor must be implemented by concrete classes');
  }
}

/// Protocol phase/stage interface
abstract class IProtocolPhase {
  /// Phase identifier
  String get id;
  
  /// Phase name
  String get name;
  
  /// Phase description
  String get description;
  
  /// Phase duration (null for variable duration)
  Duration? get duration;
  
  /// Phase type
  PhaseType get type;
  
  /// Actions to perform in this phase
  List<IProtocolAction> get actions;
  
  /// Conditions to transition to next phase
  List<ITransitionCondition> get transitionConditions;
  
  /// Execute the phase
  Future<void> execute();
  
  /// Check if phase is complete
  bool get isComplete;
  
  /// Build UI for this phase
  Widget buildUI(BuildContext context);
}

/// Protocol action interface
abstract class IProtocolAction {
  /// Action identifier
  String get id;
  
  /// Action type
  ActionType get type;
  
  /// Execute the action
  Future<void> execute();
  
  /// Action parameters
  Map<String, dynamic> get parameters;
}

/// Transition condition interface
abstract class ITransitionCondition {
  /// Condition type
  ConditionType get type;
  
  /// Check if condition is met
  bool isMet();
  
  /// Condition parameters
  Map<String, dynamic> get parameters;
}

/// Protocol state
enum ProtocolState {
  idle,
  initializing,
  ready,
  running,
  paused,
  completed,
  error,
}

/// Phase types
enum PhaseType {
  /// Preparation phase (e.g., calibration, instructions)
  preparation,
  
  /// Active measurement phase
  measurement,
  
  /// Rest/recovery phase
  rest,
  
  /// Intervention phase (e.g., stimulus presentation)
  intervention,
  
  /// Data collection phase
  collection,
  
  /// Questionnaire/survey phase
  survey,
  
  /// Custom phase
  custom,
}

/// Action types
enum ActionType {
  /// Start sensor data collection
  startSensorCollection,
  
  /// Stop sensor data collection
  stopSensorCollection,
  
  /// Display instruction
  displayInstruction,
  
  /// Play audio
  playAudio,
  
  /// Show visual stimulus
  showVisual,
  
  /// Record marker/event
  recordMarker,
  
  /// Send notification
  sendNotification,
  
  /// Execute custom code
  executeCustom,
}

/// Condition types
enum ConditionType {
  /// Time-based condition
  timeBased,
  
  /// Event count condition
  eventCount,
  
  /// User input condition
  userInput,
  
  /// Data threshold condition
  dataThreshold,
  
  /// Custom condition
  custom,
}

/// Protocol event
class ProtocolEvent {
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  final String? phaseId;
  final String? actionId;
  
  const ProtocolEvent({
    required this.type,
    required this.timestamp,
    this.data,
    this.phaseId,
    this.actionId,
  });
}

/// Protocol execution context
abstract class IProtocolContext {
  /// Get sensor data
  Stream<SensorData> getSensorData(SensorType type);
  
  /// Record event/marker
  void recordEvent(String type, Map<String, dynamic>? data);
  
  /// Get user input
  Future<T?> getUserInput<T>(String prompt, InputType inputType);
  
  /// Display message
  void displayMessage(String message, {Duration? duration});
  
  /// Play audio
  Future<void> playAudio(String assetPath);
  
  /// Get experiment metadata
  Map<String, dynamic> get metadata;
  
  /// Update metadata
  void updateMetadata(String key, dynamic value);
}

/// Input types for user interaction
enum InputType {
  text,
  number,
  boolean,
  choice,
  multiChoice,
  scale,
  datetime,
}