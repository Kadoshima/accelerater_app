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
  double? get magnitude => type == 'raw' ? data['magnitude']?.toDouble() : null;

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
