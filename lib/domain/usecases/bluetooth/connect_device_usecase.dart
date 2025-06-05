import '../../../core/utils/result.dart';
import '../../entities/bluetooth_device.dart';
import '../../repositories/bluetooth_repository.dart';

/// Bluetoothデバイスに接続するユースケース
class ConnectDeviceUseCase {
  final BluetoothRepository _repository;

  ConnectDeviceUseCase(this._repository);

  /// デバイスに接続
  Future<Result<void>> connect(String deviceId) {
    return _repository.connectDevice(deviceId);
  }

  /// デバイスから切断
  Future<Result<void>> disconnect(String deviceId) {
    return _repository.disconnectDevice(deviceId);
  }

  /// 接続状態を監視
  Stream<DeviceConnectionState> getConnectionState(String deviceId) {
    return _repository.getConnectionState(deviceId);
  }

  /// 接続済みデバイスを監視
  Stream<List<BluetoothDeviceEntity>> get connectedDevices => _repository.connectedDevices;
}