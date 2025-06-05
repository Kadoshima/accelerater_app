import 'dart:async';
import 'dart:math' as math;
import '../../domain/repositories/gait_analysis_repository.dart';
import '../../models/sensor_data.dart';
import '../../utils/gait_analysis_service.dart';

/// 歩行解析リポジトリの実装
class GaitAnalysisRepositoryImpl implements GaitAnalysisRepository {
  final GaitAnalysisService _gaitAnalysisService;
  final StreamController<GaitAnalysisState> _stateController = StreamController<GaitAnalysisState>.broadcast();
  final List<double> _spmHistory = [];
  static const int _maxHistorySize = 300; // 5分間分（1秒ごとに記録する場合）

  GaitAnalysisRepositoryImpl({
    GaitAnalysisService? gaitAnalysisService,
  }) : _gaitAnalysisService = gaitAnalysisService ?? GaitAnalysisService();

  @override
  void addSensorData(M5SensorData data) {
    _gaitAnalysisService.addSensorData(data);
    _updateSpmHistory();
    _updateState();
  }

  @override
  double get currentSpm => _gaitAnalysisService.currentSpm;

  @override
  int get stepCount => _gaitAnalysisService.stepCount;

  @override
  double get reliability => _gaitAnalysisService.reliability;

  @override
  bool get isStatic {
    // 現在のSPMが非常に低い場合は静止状態とみなす
    return currentSpm < 10.0;
  }

  @override
  List<double> get spmHistory => List.unmodifiable(_spmHistory);

  @override
  Stream<GaitAnalysisState> get stateStream => _stateController.stream;

  @override
  void reset() {
    _gaitAnalysisService.reset();
    _spmHistory.clear();
    _updateState();
  }

  @override
  GaitStability evaluateStability({
    required double targetSpm,
    required Duration evaluationPeriod,
  }) {
    // 評価期間中のSPM履歴を取得
    final samplesNeeded = evaluationPeriod.inSeconds;
    final recentSpmValues = _spmHistory.length > samplesNeeded
        ? _spmHistory.skip(_spmHistory.length - samplesNeeded).toList()
        : _spmHistory;

    if (recentSpmValues.isEmpty) {
      return const GaitStability(
        isStable: false,
        stableSeconds: 0,
        averageSpm: 0,
        spmVariance: 0,
        followRate: 0,
      );
    }

    // 平均SPMを計算
    final averageSpm = recentSpmValues.reduce((a, b) => a + b) / recentSpmValues.length;

    // 分散を計算
    double variance = 0;
    for (final spm in recentSpmValues) {
      variance += (spm - averageSpm) * (spm - averageSpm);
    }
    variance = recentSpmValues.length > 1 ? variance / (recentSpmValues.length - 1) : 0;

    // 標準偏差
    final standardDeviation = variance > 0 ? math.sqrt(variance) : 0;

    // 安定性の判定（標準偏差が5BPM以内）
    final isStable = standardDeviation < 5.0;

    // 目標SPMとの差を計算してfollow rateを算出
    final difference = (averageSpm - targetSpm).abs();
    final followRate = targetSpm > 0 ? (1 - (difference / targetSpm)) * 100 : 0;

    // 安定している秒数を計算
    int stableSeconds = 0;
    for (int i = recentSpmValues.length - 1; i >= 0; i--) {
      final spmDiff = (recentSpmValues[i] - targetSpm).abs();
      if (spmDiff <= 5.0) {
        stableSeconds++;
      } else {
        break;
      }
    }

    return GaitStability(
      isStable: isStable,
      stableSeconds: stableSeconds,
      averageSpm: averageSpm,
      spmVariance: variance,
      followRate: followRate.clamp(0.0, 100.0).toDouble(),
    );
  }

  void _updateSpmHistory() {
    if (currentSpm > 0) {
      _spmHistory.add(currentSpm);
      if (_spmHistory.length > _maxHistorySize) {
        _spmHistory.removeAt(0);
      }
    }
  }

  void _updateState() {
    _stateController.add(GaitAnalysisState(
      currentSpm: currentSpm,
      stepCount: stepCount,
      reliability: reliability,
      isStatic: isStatic,
      recentSpmValues: _spmHistory.length > 30
          ? _spmHistory.skip(_spmHistory.length - 30).toList()
          : _spmHistory,
      lastUpdate: DateTime.now(),
    ));
  }

  void dispose() {
    _stateController.close();
  }
}