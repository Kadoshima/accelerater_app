import 'dart:math' as math;

/// M5Stackから受信するセンサーデータを表すクラス
class M5SensorData {
  final String device;
  final int timestamp;
  final String type;
  final Map<String, dynamic> data;

  M5SensorData({
    required this.device,
    required this.timestamp,
    required this.type,
    required this.data,
  });

  factory M5SensorData.fromJson(Map<String, dynamic> json) {
    return M5SensorData(
      device: json['device'],
      timestamp: json['timestamp'],
      type: json['type'],
      data: json['data'],
    );
  }

  // raw または imu データからのアクセサ
  double? get accX =>
      (type == 'raw' || type == 'imu') ? data['accX']?.toDouble() : null;
  double? get accY =>
      (type == 'raw' || type == 'imu') ? data['accY']?.toDouble() : null;
  double? get accZ =>
      (type == 'raw' || type == 'imu') ? data['accZ']?.toDouble() : null;

  // 合成加速度の計算 (3軸の二乗和の平方根)
  double? get magnitude {
    if (type == 'raw' && data['magnitude'] != null) {
      return data['magnitude'].toDouble();
    } else if ((type == 'raw' || type == 'imu') &&
        accX != null &&
        accY != null &&
        accZ != null) {
      // 3軸データから合成加速度を計算
      return math.sqrt(accX! * accX! + accY! * accY! + accZ! * accZ!);
    }
    return null;
  }

  // ジャイロセンサーデータ
  double? get gyroX =>
      (type == 'raw' || type == 'imu') ? data['gyroX']?.toDouble() : null;
  double? get gyroY =>
      (type == 'raw' || type == 'imu') ? data['gyroY']?.toDouble() : null;
  double? get gyroZ =>
      (type == 'raw' || type == 'imu') ? data['gyroZ']?.toDouble() : null;

  // bpmデータからのアクセサ
  double? get bpm => type == 'bpm' ? data['bpm']?.toDouble() : null;
  int? get lastInterval => type == 'bpm' ? data['lastInterval'] : null;
}
