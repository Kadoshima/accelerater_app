import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sensors/sensor_factory.dart';
import '../../core/sensors/interfaces/sensor_interface.dart';
import '../../core/sensors/implementations/sensor_manager.dart';
import '../../core/plugins/research_plugin.dart';
import '../../services/sensor_data_recorder.dart';
import 'service_providers.dart';

/// Provider for sensor factory
final sensorFactoryProvider = Provider<SensorFactory>((ref) {
  return SensorFactory();
});

/// Provider for sensor manager
final sensorManagerProvider = Provider<ISensorManager>((ref) {
  return ref.watch(sensorFactoryProvider).createSensorManager();
});

/// Provider for available sensors
final availableSensorsProvider = StreamProvider<List<ISensor>>((ref) async* {
  final manager = ref.watch(sensorManagerProvider);
  
  // Emit current sensors initially
  yield manager.allSensors;
  
  // Watch for changes (this is a simplified version)
  // In a real implementation, you'd have a proper change notification system
  await for (final _ in Stream.periodic(const Duration(seconds: 1))) {
    yield manager.allSensors;
  }
});

/// Provider for sensor status
final sensorStatusProvider = Provider.family<SensorStatus?, String>((ref, sensorId) {
  final manager = ref.watch(sensorManagerProvider);
  final sensor = manager.getSensor(sensorId);
  return sensor?.status.value;
});

/// Provider for combined sensor data stream
final sensorDataStreamProvider = StreamProvider<SensorData>((ref) {
  final manager = ref.watch(sensorManagerProvider);
  return manager.combinedDataStream;
});

/// Provider to auto-detect sensors
final autoDetectSensorsProvider = FutureProvider<List<ISensor>>((ref) async {
  final factory = ref.watch(sensorFactoryProvider);
  final bleService = ref.watch(bleServiceProvider);
  
  return await factory.autoDetectSensors(
    bleService: bleService,
    includePhoneSensors: true,
  );
});

/// Provider for sensors by type
final sensorsByTypeProvider = Provider.family<List<ISensor>, SensorType>((ref, type) {
  final manager = ref.watch(sensorManagerProvider);
  return manager.getSensorsByType(type);
});

/// State notifier for managing sensor connections
class SensorConnectionNotifier extends StateNotifier<Map<String, bool>> {
  final ISensorManager _manager;
  
  SensorConnectionNotifier(this._manager) : super({});
  
  Future<void> connectSensor(String sensorId) async {
    final sensor = _manager.getSensor(sensorId);
    if (sensor != null) {
      await sensor.connect();
      state = {...state, sensorId: true};
    }
  }
  
  Future<void> disconnectSensor(String sensorId) async {
    final sensor = _manager.getSensor(sensorId);
    if (sensor != null) {
      await sensor.disconnect();
      state = {...state, sensorId: false};
    }
  }
  
  Future<void> connectAll() async {
    await _manager.connectAll();
    state = {
      for (final sensor in _manager.allSensors)
        sensor.id: sensor.status.value == SensorStatus.connected ||
                   sensor.status.value == SensorStatus.collecting,
    };
  }
  
  Future<void> disconnectAll() async {
    await _manager.disconnectAll();
    state = {
      for (final sensor in _manager.allSensors)
        sensor.id: false,
    };
  }
}

/// Provider for sensor connection management
final sensorConnectionProvider = 
    StateNotifierProvider<SensorConnectionNotifier, Map<String, bool>>((ref) {
  final manager = ref.watch(sensorManagerProvider);
  return SensorConnectionNotifier(manager);
});

/// Provider to check if required sensors are available
final requiredSensorsAvailableProvider = 
    FutureProvider.family<bool, List<SensorType>>((ref, requiredTypes) async {
  final manager = ref.watch(sensorManagerProvider);
  return await (manager as SensorManager).checkRequiredSensors(requiredTypes);
});

/// Provider for sensor data recorder
final sensorDataRecorderProvider = Provider<SensorDataRecorder>((ref) {
  final recorder = SensorDataRecorder();
  
  ref.onDispose(() {
    recorder.dispose();
  });
  
  return recorder;
});

/// Provider for recording status
final recordingStatusProvider = StreamProvider<RecordingStatus>((ref) {
  final recorder = ref.watch(sensorDataRecorderProvider);
  
  // 定期的にステータスを更新
  return Stream.periodic(const Duration(seconds: 1), (_) {
    return recorder.status;
  });
});

/// Provider for sync events
final syncEventsProvider = StreamProvider<SyncEvent>((ref) {
  final recorder = ref.watch(sensorDataRecorderProvider);
  return recorder.syncEvents;
});