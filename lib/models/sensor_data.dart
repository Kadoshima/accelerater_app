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

  /// CSVフォーマット用の行データを生成
  List<dynamic> toCsvRow() {
    return [
      timestamp,
      device,
      type,
      accX ?? '',
      accY ?? '',
      accZ ?? '',
      gyroX ?? '',
      gyroY ?? '',
      gyroZ ?? '',
      magnitude ?? '',
      bpm ?? '',
      lastInterval ?? '',
    ];
  }

  /// CSVヘッダーを取得
  static List<String> getCsvHeaders() {
    return [
      'timestamp',
      'device',
      'type',
      'acc_x',
      'acc_y',
      'acc_z',
      'gyro_x',
      'gyro_y',
      'gyro_z',
      'magnitude',
      'bpm',
      'last_interval',
    ];
  }
}

/// 加速度センサーデータのバッファリングクラス
class AccelerometerDataBuffer {
  final int maxBufferSize;
  final List<M5SensorData> _buffer = [];
  
  AccelerometerDataBuffer({this.maxBufferSize = 60000}); // デフォルト: 1分間分（100Hz想定）

  /// データを追加
  void add(M5SensorData data) {
    if (data.type == 'raw' || data.type == 'imu') {
      _buffer.add(data);
      
      // バッファサイズを超えたら古いデータを削除
      while (_buffer.length > maxBufferSize) {
        _buffer.removeAt(0);
      }
    }
  }

  /// バッファをクリア
  void clear() {
    _buffer.clear();
  }

  /// 現在のバッファサイズを取得
  int get size => _buffer.length;

  /// バッファデータを取得（コピーを返す）
  List<M5SensorData> get data => List.from(_buffer);

  /// 指定時間範囲のデータを取得
  List<M5SensorData> getDataInTimeRange(DateTime start, DateTime end) {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    
    return _buffer.where((data) {
      return data.timestamp >= startMs && data.timestamp <= endMs;
    }).toList();
  }

  /// メモリ使用量の推定（MB）
  double get estimatedMemoryUsageMB {
    // 1データポイントあたり約100バイトと仮定
    return (_buffer.length * 100) / (1024 * 1024);
  }
}