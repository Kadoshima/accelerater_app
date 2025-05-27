import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

/// デバイス接続画面
/// IMUと心拍センサーの両方の接続状態を管理し、グラフィカルに表示する
class DeviceConnectionScreen extends StatefulWidget {
  final Function(BluetoothDevice? imuDevice, BluetoothDevice? heartRateDevice) onConnectionComplete;
  
  const DeviceConnectionScreen({
    Key? key,
    required this.onConnectionComplete,
  }) : super(key: key);

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen>
    with TickerProviderStateMixin {
  // IMU接続関連
  BluetoothDevice? imuDevice;
  bool isImuConnected = false;
  bool isImuScanning = false;
  bool isImuConnecting = false;
  
  // 心拍センサー接続関連
  BluetoothDevice? heartRateDevice;
  bool isHeartRateConnected = false;
  bool isHeartRateScanning = false;
  bool isHeartRateConnecting = false;
  
  // スキャン結果
  final List<ScanResult> _imuScanResults = [];
  final List<ScanResult> _heartRateScanResults = [];
  
  // サービスUUID
  final Guid imuServiceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  final Guid heartRateServiceUuid = Guid("0000180d-0000-1000-8000-00805f9b34fb"); // Standard Heart Rate Service UUID
  
  // アニメーション
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  
  @override
  void initState() {
    super.initState();
    
    // パルスアニメーションの設定
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // 初期スキャン開始
    _startScanning();
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }
  
  /// 両方のデバイスをスキャンする
  Future<void> _startScanning() async {
    setState(() {
      isImuScanning = true;
      isHeartRateScanning = true;
      _imuScanResults.clear();
      _heartRateScanResults.clear();
    });
    
    try {
      // 既存の接続をチェック
      List<BluetoothDevice> connectedDevices = FlutterBluePlus.connectedDevices;
      for (var device in connectedDevices) {
        await _checkDeviceType(device);
      }
      
      // スキャン開始
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
      
      // スキャン結果を監視
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          _categorizeDevice(result);
        }
      });
      
      // タイムアウト後
      Future.delayed(const Duration(seconds: 15), () {
        if (mounted) {
          setState(() {
            isImuScanning = false;
            isHeartRateScanning = false;
          });
        }
      });
    } catch (e) {
      debugPrint('スキャンエラー: $e');
      setState(() {
        isImuScanning = false;
        isHeartRateScanning = false;
      });
    }
  }
  
  /// デバイスをカテゴリ分けする
  void _categorizeDevice(ScanResult result) {
    final deviceName = result.device.platformName.toLowerCase();
    final advertisementData = result.advertisementData;
    
    // IMUデバイスの判定（M5StickIMU）
    if (deviceName.contains('m5stick') || deviceName.contains('imu')) {
      if (!_imuScanResults.any((r) => r.device.remoteId == result.device.remoteId)) {
        setState(() {
          _imuScanResults.add(result);
        });
      }
    }
    
    // 心拍センサーの判定（Huaweiスマートウォッチ）
    if (deviceName.contains('huawei') || 
        deviceName.contains('watch') || 
        deviceName.contains('band') ||
        deviceName.contains('gt') ||
        advertisementData.serviceUuids.contains(heartRateServiceUuid)) {
      if (!_heartRateScanResults.any((r) => r.device.remoteId == result.device.remoteId)) {
        setState(() {
          _heartRateScanResults.add(result);
        });
      }
    }
  }
  
  /// 既に接続されているデバイスのタイプを確認
  Future<void> _checkDeviceType(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      
      // IMUサービスの確認
      if (services.any((service) => service.uuid == imuServiceUuid)) {
        setState(() {
          imuDevice = device;
          isImuConnected = true;
        });
        _checkConnectionComplete();
      }
      
      // 心拍サービスの確認
      if (services.any((service) => service.uuid == heartRateServiceUuid)) {
        setState(() {
          heartRateDevice = device;
          isHeartRateConnected = true;
        });
        _checkConnectionComplete();
      }
    } catch (e) {
      debugPrint('サービス確認エラー: $e');
    }
  }
  
  /// IMUデバイスに接続
  Future<void> _connectToImu(BluetoothDevice device) async {
    setState(() {
      isImuConnecting = true;
    });
    
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      
      // サービスを確認
      List<BluetoothService> services = await device.discoverServices();
      if (services.any((service) => service.uuid == imuServiceUuid)) {
        setState(() {
          imuDevice = device;
          isImuConnected = true;
          isImuConnecting = false;
        });
        _checkConnectionComplete();
      } else {
        throw Exception('IMUサービスが見つかりません');
      }
    } catch (e) {
      debugPrint('IMU接続エラー: $e');
      setState(() {
        isImuConnecting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('IMU接続エラー: $e')),
        );
      }
    }
  }
  
  /// 心拍センサーに接続
  Future<void> _connectToHeartRate(BluetoothDevice device) async {
    setState(() {
      isHeartRateConnecting = true;
    });
    
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      
      // サービスを確認
      List<BluetoothService> services = await device.discoverServices();
      if (services.any((service) => service.uuid == heartRateServiceUuid)) {
        setState(() {
          heartRateDevice = device;
          isHeartRateConnected = true;
          isHeartRateConnecting = false;
        });
        _checkConnectionComplete();
      } else {
        // Huaweiデバイスは標準の心拍サービスを使わない場合があるので、
        // 名前で判定して接続を維持
        if (device.platformName.toLowerCase().contains('huawei')) {
          setState(() {
            heartRateDevice = device;
            isHeartRateConnected = true;
            isHeartRateConnecting = false;
          });
          _checkConnectionComplete();
        } else {
          throw Exception('心拍サービスが見つかりません');
        }
      }
    } catch (e) {
      debugPrint('心拍センサー接続エラー: $e');
      setState(() {
        isHeartRateConnecting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('心拍センサー接続エラー: $e')),
        );
      }
    }
  }
  
  /// 両方の接続が完了したかチェック
  void _checkConnectionComplete() {
    if (isImuConnected && isHeartRateConnected) {
      // 少し待ってから次の画面へ
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onConnectionComplete(imuDevice, heartRateDevice);
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('デバイス接続'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // 接続状態サマリー
              _buildConnectionSummary(),
              const SizedBox(height: 30),
              
              // デバイス接続カード
              Expanded(
                child: Row(
                  children: [
                    // IMU接続カード
                    Expanded(
                      child: _buildDeviceCard(
                        title: 'IMUセンサー',
                        subtitle: 'M5StickIMU',
                        icon: Icons.sensors,
                        isConnected: isImuConnected,
                        isScanning: isImuScanning,
                        isConnecting: isImuConnecting,
                        scanResults: _imuScanResults,
                        onConnect: _connectToImu,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 20),
                    
                    // 心拍センサー接続カード
                    Expanded(
                      child: _buildDeviceCard(
                        title: '心拍センサー',
                        subtitle: 'Huawei Watch',
                        icon: Icons.favorite,
                        isConnected: isHeartRateConnected,
                        isScanning: isHeartRateScanning,
                        isConnecting: isHeartRateConnecting,
                        scanResults: _heartRateScanResults,
                        onConnect: _connectToHeartRate,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // 再スキャンボタン
              if (!isImuScanning && !isHeartRateScanning)
                ElevatedButton.icon(
                  onPressed: _startScanning,
                  icon: const Icon(Icons.refresh),
                  label: const Text('再スキャン'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 接続状態サマリー
  Widget _buildConnectionSummary() {
    int connectedCount = (isImuConnected ? 1 : 0) + (isHeartRateConnected ? 1 : 0);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: connectedCount == 2 ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: connectedCount == 2 ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            connectedCount == 2 ? Icons.check_circle : Icons.info,
            color: connectedCount == 2 ? Colors.green : Colors.orange,
            size: 30,
          ),
          const SizedBox(width: 10),
          Text(
            connectedCount == 2
                ? '全てのデバイスが接続されました'
                : '$connectedCount/2 デバイス接続済み',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: connectedCount == 2 ? Colors.green[800] : Colors.orange[800],
            ),
          ),
        ],
      ),
    );
  }
  
  /// デバイス接続カード
  Widget _buildDeviceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isConnected,
    required bool isScanning,
    required bool isConnecting,
    required List<ScanResult> scanResults,
    required Function(BluetoothDevice) onConnect,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isConnected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // アイコンとステータス
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isScanning ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isConnected ? color : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 15),
            
            // タイトル
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            
            // ステータステキスト
            Text(
              isConnected
                  ? '接続済み'
                  : isConnecting
                      ? '接続中...'
                      : isScanning
                          ? 'スキャン中...'
                          : '未接続',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isConnected ? color : Colors.grey[600],
              ),
            ),
            
            // デバイスリスト
            if (!isConnected && scanResults.isNotEmpty) ...[
              const SizedBox(height: 15),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: scanResults.length,
                  itemBuilder: (context, index) {
                    final result = scanResults[index];
                    return ListTile(
                      title: Text(
                        result.device.platformName.isNotEmpty
                            ? result.device.platformName
                            : 'Unknown Device',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        result.device.remoteId.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: ElevatedButton(
                        onPressed: isConnecting
                            ? null
                            : () => onConnect(result.device),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                        ),
                        child: const Text('接続'),
                      ),
                    );
                  },
                ),
              ),
            ] else if (!isConnected && !isScanning) ...[
              const SizedBox(height: 15),
              Text(
                'デバイスが見つかりません',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}