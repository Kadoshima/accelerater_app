import 'dart:async';
import '../../models/sensor_data.dart';

/// 歩行解析リポジトリのインターフェース
abstract class GaitAnalysisRepository {
  /// センサーデータを追加
  void addSensorData(M5SensorData data);

  /// 現在のSPM（歩数/分）を取得
  double get currentSpm;

  /// 歩数カウントを取得
  int get stepCount;

  /// 信頼性スコアを取得
  double get reliability;

  /// 静止状態かどうかを取得
  bool get isStatic;

  /// SPM履歴を取得
  List<double> get spmHistory;

  /// 歩行解析状態のストリーム
  Stream<GaitAnalysisState> get stateStream;

  /// 解析をリセット
  void reset();

  /// 歩行の安定性を評価
  GaitStability evaluateStability({
    required double targetSpm,
    required Duration evaluationPeriod,
  });
}

/// 歩行解析の状態
class GaitAnalysisState {
  final double currentSpm;
  final int stepCount;
  final double reliability;
  final bool isStatic;
  final List<double> recentSpmValues;
  final DateTime? lastUpdate;

  const GaitAnalysisState({
    required this.currentSpm,
    required this.stepCount,
    required this.reliability,
    required this.isStatic,
    this.recentSpmValues = const [],
    this.lastUpdate,
  });

  GaitAnalysisState copyWith({
    double? currentSpm,
    int? stepCount,
    double? reliability,
    bool? isStatic,
    List<double>? recentSpmValues,
    DateTime? lastUpdate,
  }) {
    return GaitAnalysisState(
      currentSpm: currentSpm ?? this.currentSpm,
      stepCount: stepCount ?? this.stepCount,
      reliability: reliability ?? this.reliability,
      isStatic: isStatic ?? this.isStatic,
      recentSpmValues: recentSpmValues ?? this.recentSpmValues,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

/// 歩行の安定性評価
class GaitStability {
  final bool isStable;
  final int stableSeconds;
  final double averageSpm;
  final double spmVariance;
  final double followRate;

  const GaitStability({
    required this.isStable,
    required this.stableSeconds,
    required this.averageSpm,
    required this.spmVariance,
    required this.followRate,
  });
}