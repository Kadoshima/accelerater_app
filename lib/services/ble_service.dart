import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/sensor_data.dart';

/// Service for managing BLE connections and data
class BleService {
  final StreamController<List<int>> _dataStreamController = 
      StreamController<List<int>>.broadcast();
  
  final StreamController<M5SensorData> _sensorDataStreamController = 
      StreamController<M5SensorData>.broadcast();
  
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _characteristicSubscription;
  
  // Buffer for incomplete JSON messages
  String _jsonBuffer = '';
  
  /// Stream of raw BLE data
  Stream<List<int>> get dataStream => _dataStreamController.stream;
  
  /// Stream of parsed M5 sensor data
  Stream<M5SensorData> get sensorDataStream => _sensorDataStreamController.stream;
  
  /// Currently connected device
  BluetoothDevice? get connectedDevice => _connectedDevice;
  
  /// Device name
  String? get deviceName => _connectedDevice?.platformName;
  
  /// Connect to a BLE device
  Future<void> connect(BluetoothDevice device) async {
    try {
      await device.connect();
      _connectedDevice = device;
      
      // Discover services
      final services = await device.discoverServices();
      
      // Find the characteristic we're interested in
      // This is a placeholder - in real implementation, you'd look for specific UUIDs
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            _characteristic = characteristic;
            await characteristic.setNotifyValue(true);
            
            _characteristicSubscription = characteristic.lastValueStream.listen((data) {
              _dataStreamController.add(data);
              _processRawData(data);
            });
            
            break;
          }
        }
        if (_characteristic != null) break;
      }
    } catch (e) {
      rethrow;
    }
  }
  
  /// Process raw BLE data and parse M5 sensor data
  void _processRawData(List<int> data) {
    try {
      // Convert bytes to string
      final String chunk = utf8.decode(data, allowMalformed: true);
      _jsonBuffer += chunk;
      
      // Try to parse complete JSON messages
      // M5Stack sends JSON data terminated by newlines
      final lines = _jsonBuffer.split('\n');
      
      // Process all complete lines except the last one (might be incomplete)
      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          _parseJsonLine(line);
        }
      }
      
      // Keep the last line (potentially incomplete) in the buffer
      _jsonBuffer = lines.last;
    } catch (e) {
      // Silently ignore errors in production
      // In debug mode, you could use: debugPrint('Error processing raw data: $e');
    }
  }
  
  /// Parse a single line of JSON data
  void _parseJsonLine(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      
      // Expected format from M5Stack:
      // {
      //   "device": "M5Stack-XXXX",
      //   "timestamp": 1234567890,
      //   "type": "raw" | "imu" | "bpm",
      //   "data": {
      //     "accX": 0.0, "accY": 0.0, "accZ": 0.0,
      //     "gyroX": 0.0, "gyroY": 0.0, "gyroZ": 0.0,
      //     "magnitude": 0.0,
      //     "bpm": 70,
      //     "lastInterval": 850
      //   }
      // }
      
      // Create M5SensorData from JSON
      final sensorData = M5SensorData.fromJson(json);
      
      // Add device name if not present
      if (sensorData.device.isEmpty && _connectedDevice != null) {
        final updatedData = M5SensorData(
          device: _connectedDevice!.remoteId.str,
          timestamp: sensorData.timestamp,
          type: sensorData.type,
          data: sensorData.data,
        );
        _sensorDataStreamController.add(updatedData);
      } else {
        _sensorDataStreamController.add(sensorData);
      }
    } catch (e) {
      // Silently ignore parse errors in production
      // In debug mode, you could use: debugPrint('Error parsing JSON line: $line, error: $e');
    }
  }
  
  /// Disconnect from the current device
  Future<void> disconnect() async {
    await _characteristicSubscription?.cancel();
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _characteristic = null;
    _jsonBuffer = '';
  }
  
  /// Write data to the device
  Future<void> write(List<int> data) async {
    if (_characteristic != null && _characteristic!.properties.write) {
      await _characteristic!.write(data);
    }
  }
  
  /// Write string command to the device
  Future<void> writeCommand(String command) async {
    final bytes = utf8.encode('$command\n');
    await write(bytes);
  }
  
  /// Send configuration to M5Stack
  Future<void> configureM5Stack({
    int samplingRate = 100,
    bool enableIMU = true,
    bool enableHeartRate = true,
  }) async {
    final config = {
      'cmd': 'config',
      'samplingRate': samplingRate,
      'enableIMU': enableIMU,
      'enableHeartRate': enableHeartRate,
    };
    await writeCommand(jsonEncode(config));
  }
  
  /// Start data collection on M5Stack
  Future<void> startM5DataCollection() async {
    await writeCommand('{"cmd": "start"}');
  }
  
  /// Stop data collection on M5Stack
  Future<void> stopM5DataCollection() async {
    await writeCommand('{"cmd": "stop"}');
  }
  
  /// Dispose of resources
  void dispose() {
    _characteristicSubscription?.cancel();
    _dataStreamController.close();
    _sensorDataStreamController.close();
  }
}