import '../../../core/utils/result.dart';
import '../../entities/bluetooth_device.dart';
import '../../repositories/bluetooth_repository.dart';

/// Bluetoothデバイスをスキャンするユースケース
class ScanDevicesUseCase {
  final BluetoothRepository _repository;

  ScanDevicesUseCase(this._repository);

  /// デバイススキャンを開始
  Future<Result<void>> startScan({
    Duration timeout = const Duration(seconds: 5),
    List<String>? serviceUuids,
  }) {
    return _repository.startScan(
      timeout: timeout,
      serviceUuids: serviceUuids,
    );
  }

  /// デバイススキャンを停止
  Future<Result<void>> stopScan() {
    return _repository.stopScan();
  }

  /// スキャン結果を監視
  Stream<List<BluetoothDeviceEntity>> get scanResults => _repository.scanResults;

  /// スキャン状態を監視
  Stream<BluetoothScanState> get scanState => _repository.scanState;
}