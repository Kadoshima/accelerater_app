import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'interfaces/sensor_interface.dart';
import 'models/sensor_data_models.dart';
import 'implementations/ble_sensor_adapter.dart';
import 'implementations/phone_sensor_adapter.dart';
import 'implementations/sensor_manager.dart';
import 'implementations/imu_sensor_combiner.dart';
import '../../services/ble_service.dart';

/// Factory for creating sensors
class SensorFactory {
  static final SensorFactory _instance = SensorFactory._internal();
  factory SensorFactory() => _instance;
  SensorFactory._internal();
  
  /// Create a sensor manager
  ISensorManager createSensorManager() {
    return SensorManager();
  }
  
  /// Create a BLE sensor from a Bluetooth device
  ISensor createBLESensor({
    required BluetoothDevice device,
    required BleService bleService,
    String? id,
    SensorConfiguration? configuration,
  }) {
    return BLESensorAdapter(
      device: device,
      bleService: bleService,
      id: id,
      initialConfig: configuration,
    );
  }
  
  /// Create phone's built-in accelerometer sensor
  ISensor createPhoneAccelerometer({
    SensorConfiguration? configuration,
  }) {
    return PhoneAccelerometerSensor(
      initialConfig: configuration,
    );
  }
  
  /// Create phone's built-in gyroscope sensor
  ISensor createPhoneGyroscope({
    SensorConfiguration? configuration,
  }) {
    return PhoneGyroscopeSensor(
      initialConfig: configuration,
    );
  }
  
  /// Create phone's built-in magnetometer sensor
  ISensor createPhoneMagnetometer({
    SensorConfiguration? configuration,
  }) {
    return PhoneMagnetometerSensor(
      initialConfig: configuration,
    );
  }
  
  /// Create all available phone sensors
  List<ISensor> createAllPhoneSensors({
    SensorConfiguration? configuration,
  }) {
    return [
      createPhoneAccelerometer(configuration: configuration),
      createPhoneGyroscope(configuration: configuration),
      createPhoneMagnetometer(configuration: configuration),
    ];
  }
  
  /// Create a combined IMU sensor from individual sensors
  ISensor createCombinedIMU({
    ISensor<AccelerometerData>? accelerometer,
    ISensor<GyroscopeData>? gyroscope,
    ISensor<MagnetometerData>? magnetometer,
    String? id,
    SensorConfiguration? configuration,
  }) {
    return IMUSensorCombiner(
      accelerometerSensor: accelerometer,
      gyroscopeSensor: gyroscope,
      magnetometerSensor: magnetometer,
      id: id,
      initialConfig: configuration,
    );
  }
  
  /// Create a combined phone IMU sensor
  ISensor createPhoneCombinedIMU({
    SensorConfiguration? configuration,
  }) {
    return createCombinedIMU(
      accelerometer: createPhoneAccelerometer(configuration: configuration) as ISensor<AccelerometerData>,
      gyroscope: createPhoneGyroscope(configuration: configuration) as ISensor<GyroscopeData>,
      magnetometer: createPhoneMagnetometer(configuration: configuration) as ISensor<MagnetometerData>,
      id: 'phone_imu',
      configuration: configuration,
    );
  }
  
  /// Auto-detect and create available sensors
  Future<List<ISensor>> autoDetectSensors({
    required BleService bleService,
    bool includePhoneSensors = true,
    Duration scanDuration = const Duration(seconds: 5),
  }) async {
    final sensors = <ISensor>[];
    
    // Add phone sensors if requested
    if (includePhoneSensors) {
      final phoneSensors = createAllPhoneSensors();
      for (final sensor in phoneSensors) {
        if (await sensor.isAvailable()) {
          sensors.add(sensor);
        }
      }
    }
    
    // Scan for BLE devices
    try {
      await FlutterBluePlus.startScan(timeout: scanDuration);
      
      // Get scan results
      final results = await FlutterBluePlus.scanResults.first;
      
      for (final result in results) {
        // Check if this is a known sensor device (e.g., M5Stack)
        if (_isKnownSensorDevice(result.device)) {
          sensors.add(createBLESensor(
            device: result.device,
            bleService: bleService,
          ));
        }
      }
      
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Handle scan errors gracefully
      // Logging handled by caller
    }
    
    return sensors;
  }
  
  /// Check if a BLE device is a known sensor device
  bool _isKnownSensorDevice(BluetoothDevice device) {
    // Check device name patterns
    final name = device.platformName.toLowerCase();
    return name.contains('m5stick') || 
           name.contains('m5stack') ||
           name.contains('sensor') ||
           name.contains('imu');
  }
}