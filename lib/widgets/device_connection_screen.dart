import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_spacing.dart';
import '../presentation/widgets/common/app_card.dart';
import '../presentation/widgets/common/app_button.dart';

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
  late AnimationController _scanController;
  late AnimationController _connectController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _connectAnimation;
  
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
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // スキャンアニメーションの設定
    _scanController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
    
    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanController,
      curve: Curves.linear,
    ));
    
    // 接続成功アニメーションの設定
    _connectController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _connectAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _connectController,
      curve: Curves.elasticOut,
    ));
    
    // 初期スキャン開始
    _startScanning();
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _connectController.dispose();
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
        _connectController.forward();
        _checkConnectionComplete();
      }
      
      // 心拍サービスの確認
      if (services.any((service) => service.uuid == heartRateServiceUuid)) {
        setState(() {
          heartRateDevice = device;
          isHeartRateConnected = true;
        });
        _connectController.forward();
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
        _connectController.forward();
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
          SnackBar(
            content: Text('IMU接続エラー: $e'),
            backgroundColor: AppColors.error,
          ),
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
        _connectController.forward();
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
          _connectController.forward();
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
          SnackBar(
            content: Text('心拍センサー接続エラー: $e'),
            backgroundColor: AppColors.error,
          ),
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'デバイス接続',
                style: AppTypography.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'センサーデバイスを接続してください',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              
              // 接続状態サマリー
              _buildConnectionSummary(),
              const SizedBox(height: AppSpacing.xxl),
              
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
                        accentColor: AppColors.accent,
                        gradientColors: [
                          AppColors.accent,
                          AppColors.accentDark,
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    
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
                        accentColor: AppColors.error,
                        gradientColors: [
                          AppColors.error,
                          AppColors.error.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              // 再スキャンボタン
              Center(
                child: AnimatedOpacity(
                  opacity: (!isImuScanning && !isHeartRateScanning) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: AppButton(
                    text: '再スキャン',
                    icon: Icons.refresh,
                    onPressed: (!isImuScanning && !isHeartRateScanning) ? _startScanning : null,
                    size: ButtonSize.large,
                  ),
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
    final bool allConnected = connectedCount == 2;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: AppCard(
        backgroundColor: allConnected 
            ? AppColors.success.withOpacity(0.1)
            : AppColors.surfaceVariant,
        border: Border.all(
          color: allConnected 
              ? AppColors.success.withOpacity(0.3)
              : AppColors.borderLight,
          width: 1,
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                allConnected ? Icons.check_circle : Icons.info_outline,
                key: ValueKey(allConnected),
                color: allConnected ? AppColors.success : AppColors.warning,
                size: AppSpacing.iconLg,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allConnected
                        ? '全てのデバイスが接続されました'
                        : '$connectedCount/2 デバイス接続済み',
                    style: AppTypography.titleMedium.copyWith(
                      color: allConnected ? AppColors.success : AppColors.textPrimary,
                    ),
                  ),
                  if (!allConnected) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    const Text(
                      '残りのデバイスを接続してください',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
    required Color accentColor,
    required List<Color> gradientColors,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: isConnected
          ? AppGradientCard(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              child: _buildCardContent(
                title: title,
                subtitle: subtitle,
                icon: icon,
                isConnected: isConnected,
                isScanning: isScanning,
                isConnecting: isConnecting,
                scanResults: scanResults,
                onConnect: onConnect,
                accentColor: accentColor,
              ),
            )
          : AppCard(
              border: Border.all(
                color: isScanning || isConnecting
                    ? accentColor.withOpacity(0.3)
                    : AppColors.borderLight,
                width: 1,
              ),
              child: _buildCardContent(
                title: title,
                subtitle: subtitle,
                icon: icon,
                isConnected: isConnected,
                isScanning: isScanning,
                isConnecting: isConnecting,
                scanResults: scanResults,
                onConnect: onConnect,
                accentColor: accentColor,
              ),
            ),
    );
  }
  
  Widget _buildCardContent({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isConnected,
    required bool isScanning,
    required bool isConnecting,
    required List<ScanResult> scanResults,
    required Function(BluetoothDevice) onConnect,
    required Color accentColor,
  }) {
    return Column(
      children: [
        // アイコンとステータス
        SizedBox(
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // スキャンアニメーション
              if (isScanning && !isConnected)
                AnimatedBuilder(
                  animation: _scanAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _scanAnimation.value * 2 * 3.14159,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              
              // パルスアニメーション
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isConnecting ? _pulseAnimation.value : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: isConnected 
                            ? Colors.white.withOpacity(0.2)
                            : accentColor.withOpacity(isScanning ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 35,
                        color: isConnected 
                            ? Colors.white
                            : (isScanning || isConnecting ? accentColor : AppColors.textTertiary),
                      ),
                    ),
                  );
                },
              ),
              
              // 接続成功チェックマーク
              if (isConnected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _connectAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _connectAnimation.value,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        
        // タイトル
        Text(
          title,
          style: AppTypography.titleLarge.copyWith(
            color: isConnected ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: isConnected ? Colors.white70 : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        
        // ステータステキスト
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: isConnected
                ? Colors.white.withOpacity(0.2)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            isConnected
                ? '接続済み'
                : isConnecting
                    ? '接続中...'
                    : isScanning
                        ? 'スキャン中...'
                        : '未接続',
            style: AppTypography.labelMedium.copyWith(
              color: isConnected 
                  ? Colors.white
                  : (isScanning || isConnecting ? accentColor : AppColors.textSecondary),
            ),
          ),
        ),
        
        // デバイスリスト
        if (!isConnected && scanResults.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Divider(color: AppColors.borderLight.withOpacity(0.5)),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              itemCount: scanResults.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final result = scanResults[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: AppCard(
                    backgroundColor: AppColors.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bluetooth,
                          size: 14,
                          color: accentColor,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.device.platformName.isNotEmpty
                                    ? result.device.platformName
                                    : 'Unknown Device',
                                style: AppTypography.labelMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'RSSI: ${result.rssi}dBm',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 10,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: isConnecting
                              ? null
                              : () => onConnect(result.device),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            minimumSize: const Size(50, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: accentColor,
                          ),
                          child: const Text(
                            '接続',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ] else if (!isConnected && !isScanning) ...[
          const SizedBox(height: AppSpacing.md),
          const Icon(
            Icons.bluetooth_disabled,
            size: AppSpacing.iconLg,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'デバイスが見つかりません',
            style: AppTypography.bodySmall,
          ),
        ],
      ],
    );
  }
}