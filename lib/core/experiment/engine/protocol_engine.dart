import 'dart:async';
import 'package:flutter/material.dart';
import '../interfaces/protocol_interface.dart';
import '../models/protocol_models.dart';
import '../../sensors/interfaces/sensor_interface.dart';
import '../../plugins/research_plugin.dart';
import '../../../services/sensor_data_recorder.dart';

/// Main protocol execution engine
class ProtocolEngine implements IProtocolContext {
  final ISensorManager _sensorManager;
  final SensorDataRecorder _dataRecorder;
  
  IExperimentProtocol? _currentProtocol;
  ProtocolState _state = ProtocolState.idle;
  int _currentPhaseIndex = 0;
  
  final StreamController<ProtocolState> _stateController = 
      StreamController<ProtocolState>.broadcast();
  final StreamController<ProtocolEvent> _eventController = 
      StreamController<ProtocolEvent>.broadcast();
  
  final Map<String, dynamic> _metadata = {};
  final Map<String, StreamSubscription> _sensorSubscriptions = {};
  
  Timer? _phaseTimer;
  BuildContext? _uiContext;
  
  ProtocolEngine({
    required ISensorManager sensorManager,
    required SensorDataRecorder dataRecorder,
  }) : _sensorManager = sensorManager,
       _dataRecorder = dataRecorder;
  
  /// Load and prepare a protocol
  Future<void> loadProtocol(IExperimentProtocol protocol) async {
    if (_state != ProtocolState.idle) {
      throw StateError('Cannot load protocol while another is active');
    }
    
    _setState(ProtocolState.initializing);
    _currentProtocol = protocol;
    _currentPhaseIndex = 0;
    
    try {
      // Validate protocol
      final validation = protocol.validate();
      if (!validation.isValid) {
        throw Exception('Protocol validation failed: ${validation.errors.join(', ')}');
      }
      
      // Check required sensors
      final sensorsAvailable = await _checkRequiredSensors(protocol.requiredSensors);
      if (!sensorsAvailable) {
        throw Exception('Required sensors not available');
      }
      
      // Initialize protocol
      await protocol.initialize();
      
      _setState(ProtocolState.ready);
    } catch (e) {
      _setState(ProtocolState.error);
      rethrow;
    }
  }
  
  /// Start protocol execution
  Future<void> startProtocol() async {
    if (_state != ProtocolState.ready || _currentProtocol == null) {
      throw StateError('Protocol not ready to start');
    }
    
    _setState(ProtocolState.running);
    _recordEvent('protocol_started', {
      'protocol': _currentProtocol!.name,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Start data recording
    _dataRecorder.startSession(
      participantId: _metadata['participantId'] ?? 'unknown',
      sessionType: _currentProtocol!.name,
      metadata: {
        'protocol': _currentProtocol!.toJson(),
        ..._metadata,
      },
    );
    
    // Execute phases sequentially
    await _executePhases();
  }
  
  /// Execute all protocol phases
  Future<void> _executePhases() async {
    final phases = _currentProtocol!.phases;
    
    while (_currentPhaseIndex < phases.length && _state == ProtocolState.running) {
      final phase = phases[_currentPhaseIndex];
      
      _recordEvent('phase_started', {
        'phase': phase.name,
        'phaseId': phase.id,
        'index': _currentPhaseIndex,
      });
      
      // Initialize phase conditions
      if (phase is ProtocolPhase) {
        for (final condition in phase.transitionConditions) {
          if (condition is TransitionCondition) {
            condition.initialize();
          }
        }
      }
      
      // Execute phase actions
      await _executePhaseActions(phase);
      
      // Wait for phase completion
      await phase.execute();
      
      _recordEvent('phase_completed', {
        'phase': phase.name,
        'phaseId': phase.id,
        'index': _currentPhaseIndex,
      });
      
      _currentPhaseIndex++;
    }
    
    // Protocol completed
    if (_state == ProtocolState.running) {
      await _completeProtocol();
    }
  }
  
  /// Execute actions for a phase
  Future<void> _executePhaseActions(IProtocolPhase phase) async {
    for (final action in phase.actions) {
      await _executeAction(action, phase.id);
    }
  }
  
  /// Execute a single action
  Future<void> _executeAction(IProtocolAction action, String phaseId) async {
    _recordEvent('action_executed', {
      'action': action.type.name,
      'actionId': action.id,
      'phaseId': phaseId,
      'parameters': action.parameters,
    });
    
    switch (action.type) {
      case ActionType.startSensorCollection:
        await _startSensorCollection(action.parameters['sensors'] ?? []);
        break;
        
      case ActionType.stopSensorCollection:
        await _stopSensorCollection();
        break;
        
      case ActionType.displayInstruction:
        _displayInstruction(action.parameters['text'] ?? '');
        break;
        
      case ActionType.playAudio:
        await playAudio(action.parameters['assetPath'] ?? '');
        break;
        
      case ActionType.showVisual:
        _showVisual(action.parameters);
        break;
        
      case ActionType.recordMarker:
        recordEvent(
          action.parameters['marker'] ?? 'marker',
          action.parameters,
        );
        break;
        
      case ActionType.sendNotification:
        _sendNotification(action.parameters['message'] ?? '');
        break;
        
      case ActionType.executeCustom:
        await action.execute();
        break;
    }
  }
  
  /// Start collecting data from specified sensors
  Future<void> _startSensorCollection(List<String> sensorTypeNames) async {
    for (final typeName in sensorTypeNames) {
      final type = SensorType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => throw ArgumentError('Unknown sensor type: $typeName'),
      );
      
      final sensors = _sensorManager.getSensorsByType(type);
      for (final sensor in sensors) {
        if (sensor.status.value == SensorStatus.connected) {
          await sensor.startDataCollection();
          
          // Subscribe to sensor data for recording
          _sensorSubscriptions[sensor.id] = sensor.dataStream.listen(
            (data) => _dataRecorder.recordSensorData(data),
          );
        }
      }
    }
  }
  
  /// Stop collecting data from all sensors
  Future<void> _stopSensorCollection() async {
    // Cancel subscriptions
    for (final subscription in _sensorSubscriptions.values) {
      await subscription.cancel();
    }
    _sensorSubscriptions.clear();
    
    // Stop sensor collection
    await _sensorManager.stopAllDataCollection();
  }
  
  /// Display instruction to user
  void _displayInstruction(String text) {
    if (_uiContext != null && _uiContext!.mounted) {
      ScaffoldMessenger.of(_uiContext!).showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
  
  /// Show visual stimulus
  void _showVisual(Map<String, dynamic> parameters) {
    // Implementation depends on UI requirements
    // Could show dialog, overlay, or navigate to specific screen
  }
  
  /// Send notification
  void _sendNotification(String message) {
    displayMessage(message);
  }
  
  /// Pause protocol execution
  Future<void> pauseProtocol() async {
    if (_state != ProtocolState.running) {
      throw StateError('Cannot pause protocol that is not running');
    }
    
    _setState(ProtocolState.paused);
    _recordEvent('protocol_paused', {
      'timestamp': DateTime.now().toIso8601String(),
      'phaseIndex': _currentPhaseIndex,
    });
    
    _phaseTimer?.cancel();
  }
  
  /// Resume protocol execution
  Future<void> resumeProtocol() async {
    if (_state != ProtocolState.paused) {
      throw StateError('Cannot resume protocol that is not paused');
    }
    
    _setState(ProtocolState.running);
    _recordEvent('protocol_resumed', {
      'timestamp': DateTime.now().toIso8601String(),
      'phaseIndex': _currentPhaseIndex,
    });
    
    // Continue with current phase
    await _executePhases();
  }
  
  /// Stop protocol execution
  Future<void> stopProtocol() async {
    if (_state == ProtocolState.idle || _state == ProtocolState.completed) {
      return;
    }
    
    _recordEvent('protocol_stopped', {
      'timestamp': DateTime.now().toIso8601String(),
      'phaseIndex': _currentPhaseIndex,
      'reason': 'user_stopped',
    });
    
    await _cleanup();
    _setState(ProtocolState.idle);
  }
  
  /// Complete protocol successfully
  Future<void> _completeProtocol() async {
    _recordEvent('protocol_completed', {
      'timestamp': DateTime.now().toIso8601String(),
      'totalPhases': _currentProtocol!.phases.length,
    });
    
    await _cleanup();
    _setState(ProtocolState.completed);
  }
  
  /// Clean up resources
  Future<void> _cleanup() async {
    _phaseTimer?.cancel();
    await _stopSensorCollection();
    await _dataRecorder.stopSession();
    _currentPhaseIndex = 0;
  }
  
  /// Check if required sensors are available
  Future<bool> _checkRequiredSensors(List<SensorType> requiredTypes) async {
    for (final type in requiredTypes) {
      final sensors = _sensorManager.getSensorsByType(type);
      if (sensors.isEmpty) {
        return false;
      }
      
      // Check if at least one sensor of this type is connected
      final hasConnected = sensors.any(
        (s) => s.status.value == SensorStatus.connected ||
               s.status.value == SensorStatus.collecting,
      );
      
      if (!hasConnected) {
        return false;
      }
    }
    return true;
  }
  
  /// Set protocol state
  void _setState(ProtocolState newState) {
    _state = newState;
    _stateController.add(newState);
  }
  
  /// Record protocol event
  void _recordEvent(String type, Map<String, dynamic>? data) {
    final event = ProtocolEvent(
      type: type,
      timestamp: DateTime.now(),
      data: data,
      phaseId: _currentPhaseIndex < (_currentProtocol?.phases.length ?? 0)
          ? _currentProtocol!.phases[_currentPhaseIndex].id
          : null,
    );
    
    _eventController.add(event);
    _dataRecorder.recordEvent(type, data);
  }
  
  // IProtocolContext implementation
  
  @override
  Stream<SensorData> getSensorData(SensorType type) {
    final sensors = _sensorManager.getSensorsByType(type);
    if (sensors.isEmpty) {
      return const Stream.empty();
    }
    
    // Return data from first available sensor of this type
    return sensors.first.dataStream;
  }
  
  @override
  void recordEvent(String type, Map<String, dynamic>? data) {
    _recordEvent(type, data);
  }
  
  @override
  Future<T?> getUserInput<T>(String prompt, InputType inputType) async {
    // Implementation depends on UI
    // Could show dialog and wait for user response
    throw UnimplementedError('User input not implemented');
  }
  
  @override
  void displayMessage(String message, {Duration? duration}) {
    if (_uiContext != null && _uiContext!.mounted) {
      ScaffoldMessenger.of(_uiContext!).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration ?? const Duration(seconds: 3),
        ),
      );
    }
  }
  
  @override
  Future<void> playAudio(String assetPath) async {
    // Implementation depends on audio library
    // Could use audioplayers package
    throw UnimplementedError('Audio playback not implemented');
  }
  
  @override
  Map<String, dynamic> get metadata => Map.unmodifiable(_metadata);
  
  @override
  void updateMetadata(String key, dynamic value) {
    _metadata[key] = value;
  }
  
  /// Set UI context for displaying messages
  void setUIContext(BuildContext context) {
    _uiContext = context;
  }
  
  /// Get current protocol
  IExperimentProtocol? get currentProtocol => _currentProtocol;
  
  /// Get current state
  ProtocolState get state => _state;
  
  /// Get state stream
  Stream<ProtocolState> get stateStream => _stateController.stream;
  
  /// Get event stream
  Stream<ProtocolEvent> get eventStream => _eventController.stream;
  
  /// Get current phase
  IProtocolPhase? get currentPhase {
    if (_currentProtocol == null || 
        _currentPhaseIndex >= _currentProtocol!.phases.length) {
      return null;
    }
    return _currentProtocol!.phases[_currentPhaseIndex];
  }
  
  /// Dispose resources
  void dispose() {
    _stateController.close();
    _eventController.close();
    _cleanup();
  }
}