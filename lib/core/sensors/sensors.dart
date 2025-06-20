/// Core sensors library
/// 
/// This library provides a unified interface for working with various sensors
/// in the research platform.

// Interfaces
export 'interfaces/sensor_interface.dart';

// Models
export 'models/sensor_data_models.dart';

// Implementations
export 'implementations/sensor_manager.dart';
export 'implementations/ble_sensor_adapter.dart';
export 'implementations/phone_sensor_adapter.dart';
export 'implementations/imu_sensor_combiner.dart';

// Factory
export 'sensor_factory.dart';