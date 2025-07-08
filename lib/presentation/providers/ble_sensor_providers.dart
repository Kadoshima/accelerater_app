import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ble_service.dart';
import '../../core/sensors/adapters/ble_service_adapter.dart';
import 'sensor_providers.dart';

/// BLEサービスプロバイダー
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// BLEサービスアダプタープロバイダー
final bleServiceAdapterProvider = Provider<BLEServiceAdapter>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  final sensorManager = ref.watch(sensorManagerProvider);
  
  final adapter = BLEServiceAdapter(
    bleService: bleService,
    sensorManager: sensorManager,
  );
  
  // 初期化
  adapter.initialize();
  
  ref.onDispose(() {
    adapter.dispose();
  });
  
  return adapter;
});

/// BLE接続状態プロバイダー
final bleConnectionStateProvider = StreamProvider<bool>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  
  // BLEデバイスの接続状態を監視
  return Stream.periodic(const Duration(seconds: 1), (_) {
    return bleService.connectedDevice != null;
  });
});

/// センサーデータストリームプロバイダー
final bleSensorDataStreamProvider = StreamProvider((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.sensorDataStream;
});