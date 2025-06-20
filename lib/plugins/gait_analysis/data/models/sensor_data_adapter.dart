import '../../domain/interfaces/gait_analyzer.dart';
import '../../../../models/sensor_data.dart' as legacy;
import '../../../../core/sensors/models/sensor_data_models.dart';

/// Adapter to convert legacy M5SensorData to GaitSensorData
class M5SensorDataAdapter implements GaitSensorData {
  final legacy.M5SensorData _legacyData;
  
  M5SensorDataAdapter(this._legacyData);
  
  @override
  double? get accelerationX => _legacyData.accX;
  
  @override
  double? get accelerationY => _legacyData.accY;
  
  @override
  double? get accelerationZ => _legacyData.accZ;
  
  @override
  double? get magnitude => _legacyData.magnitude;
  
  @override
  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(_legacyData.timestamp);
}

/// Adapter to convert generic AccelerometerData to GaitSensorData
class AccelerometerDataAdapter implements GaitSensorData {
  final AccelerometerData _data;
  
  AccelerometerDataAdapter(this._data);
  
  @override
  double? get accelerationX => _data.x;
  
  @override
  double? get accelerationY => _data.y;
  
  @override
  double? get accelerationZ => _data.z;
  
  @override
  double? get magnitude => _data.magnitude;
  
  @override
  DateTime get timestamp => _data.timestamp;
}

/// Adapter to convert IMUData to GaitSensorData
class IMUDataAdapter implements GaitSensorData {
  final IMUData _data;
  
  IMUDataAdapter(this._data);
  
  @override
  double? get accelerationX => _data.accelerometer?.x;
  
  @override
  double? get accelerationY => _data.accelerometer?.y;
  
  @override
  double? get accelerationZ => _data.accelerometer?.z;
  
  @override
  double? get magnitude => _data.accelerometer?.magnitude;
  
  @override
  DateTime get timestamp => _data.timestamp;
}

/// Factory for creating appropriate adapters
class GaitSensorDataFactory {
  static GaitSensorData fromLegacyData(legacy.M5SensorData data) {
    return M5SensorDataAdapter(data);
  }
  
  static GaitSensorData fromAccelerometerData(AccelerometerData data) {
    return AccelerometerDataAdapter(data);
  }
  
  static GaitSensorData fromIMUData(IMUData data) {
    return IMUDataAdapter(data);
  }
}