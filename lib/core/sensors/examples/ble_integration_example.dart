import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../presentation/providers/ble_sensor_providers.dart';
import '../../../presentation/providers/sensor_providers.dart';

/// BLEセンサー統合の使用例
/// 
/// このサンプルは、BLEデバイスからのセンサーデータを
/// 汎用センサーシステムで扱う方法を示しています。
class BLEIntegrationExample extends ConsumerWidget {
  const BLEIntegrationExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // BLEサービスアダプターの初期化（自動的に行われる）
    ref.watch(bleServiceAdapterProvider);
    
    // 利用可能なセンサーを監視
    final availableSensorsAsync = ref.watch(availableSensorsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Sensor Integration'),
      ),
      body: Column(
        children: [
          // BLE接続ボタン
          ElevatedButton(
            onPressed: () => _connectToM5Stack(context, ref),
            child: const Text('Connect to M5Stack'),
          ),
          
          // センサーリスト
          Expanded(
            child: availableSensorsAsync.when(
              data: (sensors) => ListView.builder(
                itemCount: sensors.length,
                itemBuilder: (context, index) {
                  final sensor = sensors[index];
                  return ListTile(
                    title: Text(sensor.info.name),
                    subtitle: Text('ID: ${sensor.id}, Type: ${sensor.type.name}'),
                    trailing: Text(sensor.status.value.name),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _connectToM5Stack(BuildContext context, WidgetRef ref) async {
    try {
      // BLEデバイスをスキャン
      final devices = await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 4),
      ).then((_) => FlutterBluePlus.scanResults.first);
      
      // M5Stackデバイスを探す
      final m5Device = devices.firstWhere(
        (result) => result.device.platformName?.contains('M5') ?? false,
        orElse: () => throw Exception('M5Stack device not found'),
      );
      
      // BLEサービスで接続
      final bleService = ref.read(bleServiceProvider);
      await bleService.connect(m5Device.device);
      
      // M5Stackの設定
      await bleService.configureM5Stack(
        samplingRate: 100,
        enableIMU: true,
        enableHeartRate: true,
      );
      
      // データ収集開始
      await bleService.startM5DataCollection();
      
      // BLEアダプターが自動的にセンサーを作成し、登録する
      // センサーマネージャーから利用可能になる
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected to M5Stack')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    }
  }
}

/// センサーデータ表示ウィジェットの例
class SensorDataDisplay extends ConsumerWidget {
  const SensorDataDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // センサーマネージャーから全センサーのデータストリームを取得
    final sensorManager = ref.watch(sensorManagerProvider);
    
    return StreamBuilder(
      stream: sensorManager.combinedDataStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: Text('No data'));
        }
        
        final data = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sensor: ${data.type.name}'),
                Text('Timestamp: ${data.timestamp}'),
                // データの内容に応じて表示を変える
                _buildDataDisplay(data),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDataDisplay(dynamic data) {
    // TODO: 各センサータイプに応じた表示を実装
    return Text('Data: ${data.toString()}');
  }
}