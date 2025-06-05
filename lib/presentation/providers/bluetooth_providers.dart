import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/bluetooth_repository_impl.dart';
import '../../domain/entities/bluetooth_device.dart';
import '../../domain/entities/heart_rate_data.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import '../../core/utils/result.dart';
import '../../models/sensor_data.dart';

/// Bluetoothリポジトリのプロバイダー
final bluetoothRepositoryProvider = Provider<BluetoothRepository>((ref) {
  return BluetoothRepositoryImpl();
});

/// Bluetoothの利用可能状態を監視するプロバイダー
final bluetoothAvailableProvider = StreamProvider<bool>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.isAvailable;
});

/// スキャン状態を監視するプロバイダー
final bluetoothScanStateProvider = StreamProvider<BluetoothScanState>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.scanState;
});

/// スキャン結果を監視するプロバイダー
final bluetoothScanResultsProvider = StreamProvider<List<BluetoothDeviceEntity>>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.scanResults;
});

/// 接続済みデバイスを監視するプロバイダー
final connectedDevicesProvider = StreamProvider<List<BluetoothDeviceEntity>>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.connectedDevices;
});

/// デバイススキャンを制御するプロバイダー
final scanControllerProvider = Provider((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  
  return ScanController(repository);
});

/// スキャンコントローラー
class ScanController {
  final BluetoothRepository _repository;
  
  ScanController(this._repository);
  
  Future<Result<void>> startScan({
    Duration timeout = const Duration(seconds: 5),
    List<String>? serviceUuids,
  }) async {
    return await _repository.startScan(
      timeout: timeout,
      serviceUuids: serviceUuids,
    );
  }
  
  Future<Result<void>> stopScan() async {
    return await _repository.stopScan();
  }
}

/// デバイス接続を制御するプロバイダー
final deviceConnectionControllerProvider = Provider((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  
  return DeviceConnectionController(repository);
});

/// デバイス接続コントローラー
class DeviceConnectionController {
  final BluetoothRepository _repository;
  
  DeviceConnectionController(this._repository);
  
  Future<Result<void>> connect(String deviceId) async {
    return await _repository.connectDevice(deviceId);
  }
  
  Future<Result<void>> disconnect(String deviceId) async {
    return await _repository.disconnectDevice(deviceId);
  }
  
  Stream<DeviceConnectionState> getConnectionState(String deviceId) {
    return _repository.getConnectionState(deviceId);
  }
}

/// 心拍数データを監視するプロバイダー（デバイスIDごと）
final heartRateStreamProvider = StreamProvider.family<Result<HeartRateData>, String>((ref, deviceId) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.getHeartRateStream(deviceId);
});

/// IMUセンサーデータを監視するプロバイダー（デバイスIDごと）
final imuSensorStreamProvider = StreamProvider.family<Result<M5SensorData>, String>((ref, deviceId) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.getImuSensorStream(deviceId);
});

/// 接続状態を監視するプロバイダー（デバイスIDごと）
final deviceConnectionStateProvider = StreamProvider.family<DeviceConnectionState, String>((ref, deviceId) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return repository.getConnectionState(deviceId);
});

/// 現在の心拍数を保持するプロバイダー
final currentHeartRateProvider = StateProvider<int?>((ref) => null);

/// 心拍数履歴を保持するプロバイダー
final heartRateHistoryProvider = StateNotifierProvider<HeartRateHistoryNotifier, List<HeartRateData>>((ref) {
  return HeartRateHistoryNotifier();
});

/// 心拍数履歴を管理するNotifier
class HeartRateHistoryNotifier extends StateNotifier<List<HeartRateData>> {
  static const int maxHistorySize = 100;
  
  HeartRateHistoryNotifier() : super([]);
  
  void addHeartRate(HeartRateData data) {
    state = [...state, data].take(maxHistorySize).toList();
  }
  
  void clear() {
    state = [];
  }
  
  List<HeartRateData> getRecent(int count) {
    if (state.length <= count) {
      return state;
    }
    return state.skip(state.length - count).toList();
  }
}