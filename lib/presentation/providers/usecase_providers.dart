import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/bluetooth/scan_devices_usecase.dart';
import '../../domain/usecases/bluetooth/connect_device_usecase.dart';
import '../../domain/usecases/bluetooth/get_heart_rate_usecase.dart';
import '../../domain/usecases/bluetooth/get_imu_data_usecase.dart';
import 'bluetooth_providers.dart';

/// Bluetoothデバイススキャンユースケースのプロバイダー
final scanDevicesUseCaseProvider = Provider<ScanDevicesUseCase>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return ScanDevicesUseCase(repository);
});

/// Bluetoothデバイス接続ユースケースのプロバイダー
final connectDeviceUseCaseProvider = Provider<ConnectDeviceUseCase>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return ConnectDeviceUseCase(repository);
});

/// 心拍数取得ユースケースのプロバイダー
final getHeartRateUseCaseProvider = Provider<GetHeartRateUseCase>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return GetHeartRateUseCase(repository);
});

/// IMUデータ取得ユースケースのプロバイダー
final getImuDataUseCaseProvider = Provider<GetImuDataUseCase>((ref) {
  final repository = ref.watch(bluetoothRepositoryProvider);
  return GetImuDataUseCase(repository);
});

/// 現在接続中のデバイスの心拍数を監視するプロバイダー
final activeHeartRateProvider = StreamProvider.autoDispose<int?>((ref) async* {
  final connectedDevices = await ref.watch(connectedDevicesProvider.future);

  if (connectedDevices.isEmpty) {
    yield null;
    return;
  }

  // 最初の接続デバイスから心拍数を取得
  final deviceId = connectedDevices.first.id;
  final useCase = ref.watch(getHeartRateUseCaseProvider);
  final stream = useCase.getHeartRateStream(deviceId);

  await for (final result in stream) {
    yield result.fold(
      (failure) => null,
      (data) => data.heartRate,
    );
  }
});

/// 平均心拍数を計算するプロバイダー
final averageHeartRateProvider = Provider<double>((ref) {
  final history = ref.watch(heartRateHistoryProvider);
  final useCase = ref.watch(getHeartRateUseCaseProvider);

  return useCase.calculateAverageHeartRate(history);
});

/// 心拍数変動を計算するプロバイダー
final heartRateVariabilityProvider = Provider<double>((ref) {
  final history = ref.watch(heartRateHistoryProvider);
  final useCase = ref.watch(getHeartRateUseCaseProvider);

  return useCase.calculateHeartRateVariability(history);
});
