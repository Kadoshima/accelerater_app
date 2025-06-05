import 'dart:async';
import '../../core/utils/result.dart';
import '../../models/experiment_models.dart';

/// 実験管理リポジトリのインターフェース
abstract class ExperimentRepository {
  /// 実験セッションを開始
  Future<Result<ExperimentSession>> startExperiment({
    required ExperimentCondition condition,
    required String subjectId,
    Map<String, dynamic>? subjectData,
    InductionVariation inductionVariation = InductionVariation.increasing,
    Map<AdvancedExperimentPhase, Duration>? customPhaseDurations,
    double inductionStepPercent = 0.05,
    int inductionStepCount = 4,
  });

  /// 実験を停止
  Future<Result<void>> stopExperiment();

  /// 現在の実験セッションを取得
  ExperimentSession? get currentSession;

  /// 実験セッションのストリーム
  Stream<ExperimentSession?> get sessionStream;

  /// フェーズ変更のストリーム
  Stream<AdvancedExperimentPhase> get phaseStream;

  /// 実験データを記録
  Future<Result<void>> recordTimeSeriesData({
    required double currentSpm,
    required double targetSpm,
    required double followRate,
    Map<String, dynamic>? additionalData,
  });

  /// 次のフェーズに進む
  Future<Result<void>> advanceToNextPhase();

  /// 主観評価を設定
  Future<Result<void>> setSubjectiveEvaluation(SubjectiveEvaluation evaluation);

  /// セッションデータを保存
  Future<Result<void>> saveSessionData(ExperimentSession session);

  /// 保存された実験データを取得
  Future<Result<List<ExperimentSession>>> getStoredSessions();

  /// 特定のセッションデータを取得
  Future<Result<ExperimentSession>> getSessionById(String sessionId);

  /// 実験データをエクスポート
  Future<Result<String>> exportSessionData(String sessionId, ExportFormat format);
}

/// エクスポート形式
enum ExportFormat {
  csv,
  json,
}