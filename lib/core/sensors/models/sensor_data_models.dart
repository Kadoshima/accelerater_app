import 'dart:math' as math;
import '../../plugins/research_plugin.dart';

/// Base accelerometer data
class AccelerometerData extends SensorData {
  final double x;
  final double y;
  final double z;
  final String sensorId;
  final Map<String, dynamic>? metadata;
  
  AccelerometerData({
    required DateTime timestamp,
    required this.x,
    required this.y,
    required this.z,
    required this.sensorId,
    this.metadata,
  }) : super(timestamp: timestamp, type: SensorType.accelerometer);
  
  /// Calculate magnitude
  double get magnitude => math.sqrt(x * x + y * y + z * z);
  
  /// Convert to map
  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'sensorId': sensorId,
    'x': x,
    'y': y,
    'z': z,
    'magnitude': magnitude,
    if (metadata != null) 'metadata': metadata,
  };
}

/// Gyroscope data
class GyroscopeData extends SensorData {
  final double x;  // rotation around x-axis (rad/s)
  final double y;  // rotation around y-axis (rad/s)
  final double z;  // rotation around z-axis (rad/s)
  final String sensorId;
  final Map<String, dynamic>? metadata;
  
  GyroscopeData({
    required DateTime timestamp,
    required this.x,
    required this.y,
    required this.z,
    required this.sensorId,
    this.metadata,
  }) : super(timestamp: timestamp, type: SensorType.gyroscope);
  
  /// Calculate angular velocity magnitude
  double get magnitude => math.sqrt(x * x + y * y + z * z);
  
  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'sensorId': sensorId,
    'x': x,
    'y': y,
    'z': z,
    'magnitude': magnitude,
    if (metadata != null) 'metadata': metadata,
  };
}

/// Magnetometer data
class MagnetometerData extends SensorData {
  final double x;  // magnetic field strength x-axis (μT)
  final double y;  // magnetic field strength y-axis (μT)
  final double z;  // magnetic field strength z-axis (μT)
  final String sensorId;
  final Map<String, dynamic>? metadata;
  
  MagnetometerData({
    required DateTime timestamp,
    required this.x,
    required this.y,
    required this.z,
    required this.sensorId,
    this.metadata,
  }) : super(timestamp: timestamp, type: SensorType.magnetometer);
  
  double get magnitude => math.sqrt(x * x + y * y + z * z);
  
  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'sensorId': sensorId,
    'x': x,
    'y': y,
    'z': z,
    'magnitude': magnitude,
    if (metadata != null) 'metadata': metadata,
  };
}

/// Heart rate data
class HeartRateData extends SensorData {
  final int bpm;
  final double? confidence;
  final List<int>? rrIntervals;
  final String sensorId;
  final Map<String, dynamic>? metadata;
  
  HeartRateData({
    required DateTime timestamp,
    required this.bpm,
    required this.sensorId,
    this.confidence,
    this.rrIntervals,
    this.metadata,
  }) : super(timestamp: timestamp, type: SensorType.heartRate);
  
  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'sensorId': sensorId,
    'bpm': bpm,
    if (confidence != null) 'confidence': confidence,
    if (rrIntervals != null) 'rrIntervals': rrIntervals,
    if (metadata != null) 'metadata': metadata,
  };
}

/// GPS data
class GPSData extends SensorData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final double? bearing;
  
  GPSData({
    required DateTime timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    this.bearing,
  }) : super(timestamp: timestamp, type: SensorType.gps);
  
  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    if (altitude != null) 'altitude': altitude,
    if (accuracy != null) 'accuracy': accuracy,
    if (speed != null) 'speed': speed,
    if (bearing != null) 'bearing': bearing,
  };
}

/// Combined IMU data (accelerometer + gyroscope + magnetometer)
class IMUData extends SensorData {
  final AccelerometerData? accelerometer;
  final GyroscopeData? gyroscope;
  final MagnetometerData? magnetometer;
  final String sensorId;
  final Map<String, dynamic>? metadata;
  
  IMUData({
    required DateTime timestamp,
    required this.sensorId,
    this.accelerometer,
    this.gyroscope,
    this.magnetometer,
    this.metadata,
  }) : super(
    timestamp: timestamp,
    type: SensorType.accelerometer, // Primary type
  );
  
  bool get hasAllSensors => 
    accelerometer != null && 
    gyroscope != null && 
    magnetometer != null;
  
  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'sensorId': sensorId,
    if (accelerometer != null) 'accelerometer': accelerometer!.toMap(),
    if (gyroscope != null) 'gyroscope': gyroscope!.toMap(),
    if (magnetometer != null) 'magnetometer': magnetometer!.toMap(),
    if (metadata != null) 'metadata': metadata,
  };
}

/// Extension to add convenience methods
extension SensorDataExtensions on SensorData {
  /// Calculate time difference from another sensor data
  Duration timeDifference(SensorData other) {
    return timestamp.difference(other.timestamp).abs();
  }
  
  /// Check if data is within time window
  bool isWithinTimeWindow(DateTime start, DateTime end) {
    return timestamp.isAfter(start) && timestamp.isBefore(end);
  }
}