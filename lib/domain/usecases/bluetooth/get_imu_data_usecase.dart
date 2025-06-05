import 'dart:math' as math;

import '../../../core/utils/result.dart';
import '../../../models/sensor_data.dart';
import '../../repositories/bluetooth_repository.dart';

/// IMUセンサーデータを取得するユースケース
class GetImuDataUseCase {
  final BluetoothRepository _repository;

  GetImuDataUseCase(this._repository);

  /// IMUセンサーデータストリームを取得
  Stream<Result<M5SensorData>> getImuSensorStream(String deviceId) {
    return _repository.getImuSensorStream(deviceId);
  }

  /// 加速度の大きさを計算
  double calculateAccelerationMagnitude(M5SensorData data) {
    final accX = data.accX ?? 0;
    final accY = data.accY ?? 0;
    final accZ = data.accZ ?? 0;
    return math.sqrt(accX * accX + accY * accY + accZ * accZ);
  }

  /// ジャイロスコープの大きさを計算
  double calculateGyroscopeMagnitude(M5SensorData data) {
    final gyroX = data.gyroX ?? 0;
    final gyroY = data.gyroY ?? 0;
    final gyroZ = data.gyroZ ?? 0;
    return math.sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);
  }

  /// センサーデータの妥当性を検証
  bool isValidSensorData(M5SensorData data) {
    // 加速度の妥当性チェック（通常の動作範囲内か）
    final accMag = calculateAccelerationMagnitude(data);
    if (accMag < 0.1 || accMag > 50.0) return false;

    // ジャイロスコープの妥当性チェック
    final gyroMag = calculateGyroscopeMagnitude(data);
    if (gyroMag > 1000.0) return false;

    // タイムスタンプの妥当性チェック
    final now = DateTime.now();
    final sensorTime = DateTime.fromMillisecondsSinceEpoch(data.timestamp);
    final diff = now.difference(sensorTime).inMinutes.abs();
    if (diff > 5) return false;

    return true;
  }
}