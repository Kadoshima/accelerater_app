import 'package:freezed_annotation/freezed_annotation.dart';

part 'bluetooth_device.freezed.dart';

/// Bluetoothデバイスのエンティティ
@freezed
class BluetoothDeviceEntity with _$BluetoothDeviceEntity {
  const factory BluetoothDeviceEntity({
    required String id,
    required String name,
    required BluetoothDeviceType type,
    required bool isConnected,
    int? rssi,
    Map<String, dynamic>? manufacturerData,
  }) = _BluetoothDeviceEntity;
}

/// デバイスタイプ
enum BluetoothDeviceType {
  heartRate,
  imuSensor,
  unknown,
}

/// 接続状態
enum DeviceConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/// スキャン状態
enum BluetoothScanState {
  idle,
  scanning,
  stopped,
}