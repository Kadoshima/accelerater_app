import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/logger_service.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/bluetooth_device.dart';
import '../../domain/entities/heart_rate_data.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import '../../models/sensor_data.dart';

/// Bluetoothリポジトリの実装
class BluetoothRepositoryImpl implements BluetoothRepository {
  final Map<String, BluetoothDevice> _devices = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  @override
  Stream<bool> get isAvailable => FlutterBluePlus.adapterState
      .map((state) => state == BluetoothAdapterState.on);

  @override
  Stream<BluetoothScanState> get scanState =>
      FlutterBluePlus.isScanning.map((isScanning) =>
          isScanning ? BluetoothScanState.scanning : BluetoothScanState.idle);

  @override
  Stream<List<BluetoothDeviceEntity>> get connectedDevices =>
      Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
        final devices = FlutterBluePlus.connectedDevices;
        return devices.map(_mapToEntity).toList();
      });

  @override
  Future<Result<void>> startScan({
    Duration timeout = const Duration(seconds: 5),
    List<String>? serviceUuids,
  }) async {
    return Results.tryAsync(() async {
      logger.info('Bluetooth scan started');

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        throw const BluetoothException(
          message: 'Bluetooth is not available',
          code: 'BLUETOOTH_NOT_AVAILABLE',
        );
      }

      await FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: serviceUuids?.map((uuid) => Guid(uuid)).toList() ?? [],
      );
    }, onError: (error, stackTrace) {
      logger.error('Bluetooth scan failed', error, stackTrace);
      return BluetoothException(
        message: 'Failed to start Bluetooth scan',
        originalError: error,
      );
    });
  }

  @override
  Future<Result<void>> stopScan() async {
    return Results.tryAsync(() async {
      await FlutterBluePlus.stopScan();
      logger.info('Bluetooth scan stopped');
    });
  }

  @override
  Stream<List<BluetoothDeviceEntity>> get scanResults => FlutterBluePlus
      .scanResults
      .map((results) => results.map((r) => _mapScanResultToEntity(r)).toList());

  @override
  Future<Result<void>> connectDevice(String deviceId) async {
    return Results.tryAsync(() async {
      final device = _devices[deviceId];
      if (device == null) {
        throw DeviceConnectionException(
          message: 'Device not found: $deviceId',
          code: 'DEVICE_NOT_FOUND',
        );
      }

      logger.info('Connecting to device: ${device.platformName}');

      await device.connect(
        timeout: BleConstants.connectionTimeout,
        autoConnect: false,
      );

      await device.discoverServices();
      logger.info('Connected to device: ${device.platformName}');
    }, onError: (error, stackTrace) {
      logger.error('Device connection failed', error, stackTrace);
      return DeviceConnectionException(
        message: 'Failed to connect to device',
        originalError: error,
      );
    });
  }

  @override
  Future<Result<void>> disconnectDevice(String deviceId) async {
    return Results.tryAsync(() async {
      final device = _devices[deviceId];
      if (device == null) {
        return;
      }

      // Clean up subscriptions
      await _subscriptions[deviceId]?.cancel();
      _subscriptions.remove(deviceId);

      await device.disconnect();
      logger.info('Disconnected from device: ${device.platformName}');
    });
  }

  @override
  Stream<Result<HeartRateData>> getHeartRateStream(String deviceId) async* {
    final device = _devices[deviceId];
    if (device == null) {
      yield Results.failure(
        DeviceConnectionException(
          message: 'Device not found: $deviceId',
          code: 'DEVICE_NOT_FOUND',
        ),
      );
      return;
    }

    try {
      final services = device.servicesList;
      BluetoothCharacteristic? heartRateChar;

      // Find heart rate characteristic
      for (final service in services) {
        if (service.uuid.toString() == BleConstants.heartRateServiceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid.toString() ==
                BleConstants.heartRateMeasurementCharUuid) {
              heartRateChar = char;
              break;
            }
          }
        }
      }

      heartRateChar ??= _findHuaweiCharacteristic(services);

      if (heartRateChar == null) {
        yield Results.failure(
          const BluetoothException(
            message: 'Heart rate characteristic not found',
            code: 'CHARACTERISTIC_NOT_FOUND',
          ),
        );
        return;
      }

      await heartRateChar.setNotifyValue(true);

      await for (final data in heartRateChar.lastValueStream) {
        yield _parseHeartRateData(data);
      }
    } catch (error, stackTrace) {
      logger.error('Heart rate stream error', error, stackTrace);
      yield Results.failure(
        BluetoothException(
          message: 'Failed to get heart rate stream',
          originalError: error,
        ),
      );
    }
  }

  @override
  Stream<Result<M5SensorData>> getImuSensorStream(String deviceId) async* {
    final device = _devices[deviceId];
    if (device == null) {
      yield Results.failure(
        DeviceConnectionException(
          message: 'Device not found: $deviceId',
          code: 'DEVICE_NOT_FOUND',
        ),
      );
      return;
    }

    try {
      final services = device.servicesList;
      BluetoothCharacteristic? imuChar;

      // Find IMU characteristic
      for (final service in services) {
        if (service.uuid.toString() == BleConstants.imuServiceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid.toString() == BleConstants.imuCharacteristicUuid) {
              imuChar = char;
              break;
            }
          }
        }
      }

      if (imuChar == null) {
        yield Results.failure(
          const BluetoothException(
            message: 'IMU characteristic not found',
            code: 'CHARACTERISTIC_NOT_FOUND',
          ),
        );
        return;
      }

      await imuChar.setNotifyValue(true);

      await for (final data in imuChar.lastValueStream) {
        yield _parseImuData(data);
      }
    } catch (error, stackTrace) {
      logger.error('IMU sensor stream error', error, stackTrace);
      yield Results.failure(
        BluetoothException(
          message: 'Failed to get IMU sensor stream',
          originalError: error,
        ),
      );
    }
  }

  @override
  Stream<DeviceConnectionState> getConnectionState(String deviceId) {
    final device = _devices[deviceId];
    if (device == null) {
      return Stream.value(DeviceConnectionState.disconnected);
    }

    return device.connectionState.map((state) {
      switch (state) {
        case BluetoothConnectionState.disconnected:
          return DeviceConnectionState.disconnected;
        case BluetoothConnectionState.connected:
          return DeviceConnectionState.connected;
        default:
          return DeviceConnectionState.disconnected;
      }
    });
  }

  // Helper methods
  BluetoothDeviceEntity _mapToEntity(BluetoothDevice device) {
    _devices[device.remoteId.str] = device;

    return BluetoothDeviceEntity(
      id: device.remoteId.str,
      name: device.platformName.isNotEmpty
          ? device.platformName
          : 'Unknown Device',
      type: _determineDeviceType(device),
      isConnected: device.isConnected,
    );
  }

  BluetoothDeviceEntity _mapScanResultToEntity(ScanResult result) {
    _devices[result.device.remoteId.str] = result.device;

    return BluetoothDeviceEntity(
      id: result.device.remoteId.str,
      name: result.device.platformName.isNotEmpty
          ? result.device.platformName
          : 'Unknown Device',
      type: _determineDeviceTypeFromScan(result),
      isConnected: false,
      rssi: result.rssi,
      manufacturerData: result.advertisementData.manufacturerData.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }

  BluetoothDeviceType _determineDeviceType(BluetoothDevice device) {
    final name = device.platformName.toLowerCase();
    if (name.contains('m5stick')) {
      return BluetoothDeviceType.imuSensor;
    } else if (name.contains('heart') || name.contains('hr')) {
      return BluetoothDeviceType.heartRate;
    }
    return BluetoothDeviceType.unknown;
  }

  BluetoothDeviceType _determineDeviceTypeFromScan(ScanResult result) {
    final name = result.device.platformName.toLowerCase();
    final serviceUuids = result.advertisementData.serviceUuids;

    if (name.contains('m5stick')) {
      return BluetoothDeviceType.imuSensor;
    }

    for (final uuid in serviceUuids) {
      if (uuid.toString() == BleConstants.heartRateServiceUuid) {
        return BluetoothDeviceType.heartRate;
      } else if (uuid.toString() == BleConstants.imuServiceUuid) {
        return BluetoothDeviceType.imuSensor;
      }
    }

    if (name.contains('heart') || name.contains('hr')) {
      return BluetoothDeviceType.heartRate;
    }

    return BluetoothDeviceType.unknown;
  }

  BluetoothCharacteristic? _findHuaweiCharacteristic(
      List<BluetoothService> services) {
    for (final service in services) {
      for (final char in service.characteristics) {
        if (char.properties.notify) {
          return char;
        }
      }
    }
    return null;
  }

  Result<HeartRateData> _parseHeartRateData(List<int> data) {
    try {
      if (data.isEmpty) {
        throw const DataParsingException(
          message: 'Empty heart rate data',
          code: 'EMPTY_DATA',
        );
      }

      int heartRate;
      HeartRateDataSource source;

      // Check for Huawei protocol
      if (data.length >= 2 &&
          data[0] == BleConstants.huaweiHeaderByte1 &&
          data[1] == BleConstants.huaweiHeaderByte2) {
        if (data.length >= 10 &&
            data[4] == BleConstants.huaweiHeartRateCommand) {
          heartRate = data[9];
          source = HeartRateDataSource.huaweiProtocol;
        } else {
          throw const DataParsingException(
            message: 'Invalid Huawei protocol data',
            code: 'INVALID_HUAWEI_DATA',
          );
        }
      } else {
        // Standard BLE protocol
        final flags = data[0];
        final isHeartRate16Bit = (flags & 0x01) != 0;

        if (isHeartRate16Bit && data.length >= 3) {
          heartRate = data[1] | (data[2] << 8);
        } else if (data.length >= 2) {
          heartRate = data[1];
        } else {
          throw const DataParsingException(
            message: 'Invalid standard BLE data',
            code: 'INVALID_BLE_DATA',
          );
        }
        source = HeartRateDataSource.standardBle;
      }

      // Validate heart rate range
      if (heartRate < BleConstants.minHeartRate ||
          heartRate > BleConstants.maxHeartRate) {
        throw DataParsingException(
          message: 'Heart rate out of range: $heartRate',
          code: 'HEART_RATE_OUT_OF_RANGE',
        );
      }

      return Results.success(
        HeartRateData(
          heartRate: heartRate,
          timestamp: DateTime.now(),
          source: source,
        ),
      );
    } catch (error) {
      if (error is AppException) {
        return Results.failure(error);
      }
      return Results.failure(
        DataParsingException(
          message: 'Failed to parse heart rate data',
          originalError: error,
        ),
      );
    }
  }

  Result<M5SensorData> _parseImuData(List<int> data) {
    try {
      if (data.isEmpty) {
        throw const DataParsingException(
          message: 'Empty IMU data',
          code: 'EMPTY_DATA',
        );
      }

      final jsonString = String.fromCharCodes(data);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final sensorData = M5SensorData.fromJson(jsonData);

      return Results.success(sensorData);
    } catch (error) {
      return Results.failure(
        DataParsingException(
          message: 'Failed to parse IMU data',
          originalError: error,
        ),
      );
    }
  }
}
