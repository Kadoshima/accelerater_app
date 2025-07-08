import 'dart:async';
import 'package:flutter/foundation.dart';
import '../interfaces/sensor_interface.dart';
import '../../plugins/research_plugin.dart';

/// Default implementation of sensor manager
class SensorManager implements ISensorManager {
  final Map<String, ISensor> _sensors = {};
  final StreamController<SensorData> _combinedStreamController = 
      StreamController<SensorData>.broadcast();
  final Map<String, StreamSubscription> _subscriptions = {};
  
  @override
  void registerSensor(ISensor sensor) {
    if (_sensors.containsKey(sensor.id)) {
      throw StateError('Sensor with ID ${sensor.id} is already registered');
    }
    
    _sensors[sensor.id] = sensor;
    
    // Subscribe to sensor data stream
    _subscriptions[sensor.id] = sensor.dataStream.listen(
      (data) => _combinedStreamController.add(data),
      onError: (error) => debugPrint('Error from sensor ${sensor.id}: $error'),
    );
    
    debugPrint('Sensor registered: ${sensor.info.name} (${sensor.id})');
  }
  
  @override
  void unregisterSensor(String sensorId) {
    final sensor = _sensors[sensorId];
    if (sensor == null) {
      throw StateError('Sensor with ID $sensorId not found');
    }
    
    // Cancel subscription
    _subscriptions[sensorId]?.cancel();
    _subscriptions.remove(sensorId);
    
    // Remove sensor
    _sensors.remove(sensorId);
    
    debugPrint('Sensor unregistered: ${sensor.info.name} (${sensor.id})');
  }
  
  @override
  ISensor? getSensor(String sensorId) => _sensors[sensorId];
  
  @override
  List<ISensor> getSensorsByType(SensorType type) {
    return _sensors.values.where((sensor) => sensor.type == type).toList();
  }
  
  @override
  List<ISensor> get allSensors => _sensors.values.toList();
  
  @override
  Future<void> connectAll() async {
    final futures = <Future>[];
    
    for (final sensor in _sensors.values) {
      if (sensor.status.value != SensorStatus.connected) {
        futures.add(
          sensor.connect().catchError((error) {
            debugPrint('Failed to connect sensor ${sensor.id}: $error');
            return null;
          }),
        );
      }
    }
    
    await Future.wait(futures);
  }
  
  @override
  Future<void> disconnectAll() async {
    final futures = <Future>[];
    
    for (final sensor in _sensors.values) {
      if (sensor.status.value != SensorStatus.disconnected) {
        futures.add(
          sensor.disconnect().catchError((error) {
            debugPrint('Failed to disconnect sensor ${sensor.id}: $error');
            return null;
          }),
        );
      }
    }
    
    await Future.wait(futures);
  }
  
  @override
  Future<void> startAllDataCollection() async {
    final futures = <Future>[];
    
    for (final sensor in _sensors.values) {
      if (sensor.status.value == SensorStatus.connected) {
        futures.add(
          sensor.startDataCollection().catchError((error) {
            debugPrint('Failed to start data collection for sensor ${sensor.id}: $error');
            return null;
          }),
        );
      }
    }
    
    await Future.wait(futures);
  }
  
  @override
  Future<void> stopAllDataCollection() async {
    final futures = <Future>[];
    
    for (final sensor in _sensors.values) {
      if (sensor.status.value == SensorStatus.collecting) {
        futures.add(
          sensor.stopDataCollection().catchError((error) {
            debugPrint('Failed to stop data collection for sensor ${sensor.id}: $error');
            return null;
          }),
        );
      }
    }
    
    await Future.wait(futures);
  }
  
  @override
  Stream<SensorData> get combinedDataStream => _combinedStreamController.stream;
  
  @override
  Future<void> dispose() async {
    // Stop all data collection
    await stopAllDataCollection();
    
    // Disconnect all sensors
    await disconnectAll();
    
    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    // Clear sensors
    _sensors.clear();
    
    // Close stream controller
    await _combinedStreamController.close();
  }
  
  /// Get status summary of all sensors
  Map<String, SensorStatus> getStatusSummary() {
    return {
      for (final sensor in _sensors.values)
        sensor.id: sensor.status.value,
    };
  }
  
  /// Check if all required sensors are available
  Future<bool> checkRequiredSensors(List<SensorType> requiredTypes) async {
    for (final type in requiredTypes) {
      final sensorsOfType = getSensorsByType(type);
      if (sensorsOfType.isEmpty) {
        return false;
      }
      
      // Check if at least one sensor of this type is available
      bool hasAvailable = false;
      for (final sensor in sensorsOfType) {
        if (await sensor.isAvailable()) {
          hasAvailable = true;
          break;
        }
      }
      
      if (!hasAvailable) {
        return false;
      }
    }
    
    return true;
  }
}