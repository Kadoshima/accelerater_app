import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sensors/sensors.dart';
import '../../core/plugins/research_plugin.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../providers/sensor_providers.dart';
import '../providers/service_providers.dart';
import 'common/app_button.dart';
import 'common/app_card.dart';

/// センサー選択ダイアログ
class SensorSelectionDialog extends ConsumerStatefulWidget {
  const SensorSelectionDialog({Key? key}) : super(key: key);

  @override
  ConsumerState<SensorSelectionDialog> createState() =>
      _SensorSelectionDialogState();
}

class _SensorSelectionDialogState extends ConsumerState<SensorSelectionDialog> {
  final Set<String> _selectedSensorIds = {};
  bool _isScanning = false;
  List<ISensor> _availableSensors = [];

  @override
  void initState() {
    super.initState();
    _startSensorDetection();
  }

  Future<void> _startSensorDetection() async {
    setState(() {
      _isScanning = true;
    });

    try {
      final factory = ref.read(sensorFactoryProvider);
      final bleService = ref.read(bleServiceProvider);
      
      // 自動検出でセンサーを探す
      final sensors = await factory.autoDetectSensors(
        bleService: bleService,
        includePhoneSensors: true,
      );

      setState(() {
        _availableSensors = sensors;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('センサー検出エラー: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _connectSelectedSensors() async {
    if (_selectedSensorIds.isEmpty) return;

    final manager = ref.read(sensorManagerProvider);
    
    // 選択されたセンサーをマネージャーに登録
    for (final sensor in _availableSensors) {
      if (_selectedSensorIds.contains(sensor.id)) {
        manager.registerSensor(sensor);
      }
    }

    // 全てのセンサーに接続
    await manager.connectAll();
    
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'センサー選択',
                  style: AppTypography.headlineMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            
            if (_isScanning)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'センサーを検索中...',
                        style: AppTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
            else if (_availableSensors.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sensors_off,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '利用可能なセンサーが見つかりません',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        onPressed: _startSensorDetection,
                        text: '再スキャン',
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableSensors.length,
                  itemBuilder: (context, index) {
                    final sensor = _availableSensors[index];
                    final isSelected = _selectedSensorIds.contains(sensor.id);
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedSensorIds.remove(sensor.id);
                            } else {
                              _selectedSensorIds.add(sensor.id);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value ?? false) {
                                      _selectedSensorIds.add(sensor.id);
                                    } else {
                                      _selectedSensorIds.remove(sensor.id);
                                    }
                                  });
                                },
                                activeColor: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sensor.info.name,
                                      style: AppTypography.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      _getSensorDescription(sensor),
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _getSensorIcon(sensor.type),
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: AppSpacing.lg),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('キャンセル'),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  onPressed: _selectedSensorIds.isNotEmpty
                      ? _connectSelectedSensors
                      : null,
                  text: '接続',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getSensorDescription(ISensor sensor) {
    final info = sensor.info;
    final parts = <String>[];
    
    if (info.manufacturer != 'Unknown') {
      parts.add(info.manufacturer);
    }
    
    if (info.model != 'Unknown') {
      parts.add(info.model);
    }
    
    parts.add(_getSensorTypeName(sensor.type));
    
    return parts.join(' • ');
  }

  String _getSensorTypeName(SensorType type) {
    switch (type) {
      case SensorType.accelerometer:
        return '加速度センサー';
      case SensorType.gyroscope:
        return 'ジャイロスコープ';
      case SensorType.magnetometer:
        return '磁力計';
      case SensorType.heartRate:
        return '心拍センサー';
      case SensorType.gps:
        return 'GPS';
      default:
        return 'その他';
    }
  }

  IconData _getSensorIcon(SensorType type) {
    switch (type) {
      case SensorType.accelerometer:
        return Icons.speed;
      case SensorType.gyroscope:
        return Icons.rotate_right;
      case SensorType.magnetometer:
        return Icons.explore;
      case SensorType.heartRate:
        return Icons.favorite;
      case SensorType.gps:
        return Icons.location_on;
      default:
        return Icons.sensors;
    }
  }
}