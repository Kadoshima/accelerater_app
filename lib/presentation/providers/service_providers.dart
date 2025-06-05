import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/metronome.dart';
import '../../services/native_metronome.dart';
import '../../services/background_service.dart';
import '../../utils/gait_analysis_service.dart';
import '../../services/experiment_controller.dart';
import '../../core/utils/logger_service.dart';

/// ロガーサービスのプロバイダー
final loggerServiceProvider = Provider<LoggerService>((ref) {
  return LoggerService();
});

/// メトロノームサービスのプロバイダー
final metronomeServiceProvider = Provider<Metronome>((ref) {
  return Metronome();
});

/// ネイティブメトロノームサービスのプロバイダー
final nativeMetronomeServiceProvider = Provider<NativeMetronome>((ref) {
  return NativeMetronome();
});

/// 歩行分析サービスのプロバイダー
final gaitAnalysisServiceProvider = Provider<GaitAnalysisService>((ref) {
  return GaitAnalysisService(
    totalDataSeconds: 6,
    windowSizeSeconds: 3,
    slideIntervalSeconds: 1,
    smoothingFactor: 0.8,
    minSpm: 40,
    maxSpm: 180,
    minReliability: 0.3,
    staticThreshold: 0.2,
    useSingleAxisOnly: true,
    verticalAxis: 'z',
  );
});

/// 実験コントローラーのプロバイダー
final experimentControllerProvider = Provider<ExperimentController>((ref) {
  final gaitAnalysisService = ref.watch(gaitAnalysisServiceProvider);
  final metronome = ref.watch(metronomeServiceProvider);
  final nativeMetronome = ref.watch(nativeMetronomeServiceProvider);
  
  return ExperimentController(
    gaitAnalysisService: gaitAnalysisService,
    metronome: metronome,
    nativeMetronome: nativeMetronome,
  );
});

/// バックグラウンドサービスの初期化状態を管理するプロバイダー
final backgroundServiceInitializedProvider = FutureProvider<void>((ref) async {
  await BackgroundService.initialize();
});

/// バックグラウンドサービスの実行状態を管理するプロバイダー
final backgroundServiceRunningProvider = StateProvider<bool>((ref) {
  return false;
});

/// バックグラウンドサービスの制御用プロバイダー
final backgroundServiceControllerProvider = Provider((ref) {
  return BackgroundServiceController();
});

/// バックグラウンドサービスコントローラー
class BackgroundServiceController {
  Future<void> start() async {
    await BackgroundService.startService();
  }
  
  Future<void> stop() async {
    await BackgroundService.stopService();
  }
  
  Future<bool> isRunning() async {
    return BackgroundService.isRunning;
  }
  
  void sendToBackground(Map<String, dynamic> data) {
    BackgroundService.service.invoke('update', data);
  }
}