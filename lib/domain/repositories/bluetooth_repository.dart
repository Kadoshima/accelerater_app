import 'dart:async';
import '../../core/utils/result.dart';
import '../entities/bluetooth_device.dart';
import '../entities/heart_rate_data.dart';
import '../../models/sensor_data.dart';

/// Bluetoothリポジトリのインターフェース
abstract class BluetoothRepository {
  /// Bluetoothの利用可能状態を取得
  Stream<bool> get isAvailable;

  /// スキャン状態を取得
  Stream<BluetoothScanState> get scanState;

  /// 接続済みデバイスのリストを取得
  Stream<List<BluetoothDeviceEntity>> get connectedDevices;

  /// デバイスをスキャン
  Future<Result<void>> startScan({
    Duration timeout = const Duration(seconds: 5),
    List<String>? serviceUuids,
  });

  /// スキャンを停止
  Future<Result<void>> stopScan();

  /// スキャン結果を取得
  Stream<List<BluetoothDeviceEntity>> get scanResults;

  /// デバイスに接続
  Future<Result<void>> connectDevice(String deviceId);

  /// デバイスから切断
  Future<Result<void>> disconnectDevice(String deviceId);

  /// 心拍数データのストリームを取得
  Stream<Result<HeartRateData>> getHeartRateStream(String deviceId);

  /// IMUセンサーデータのストリームを取得
  Stream<Result<M5SensorData>> getImuSensorStream(String deviceId);

  /// デバイスの接続状態を取得
  Stream<DeviceConnectionState> getConnectionState(String deviceId);
}