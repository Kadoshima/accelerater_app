import 'dart:async';
import 'package:flutter/material.dart';
import 'experiment_condition_manager.dart';
import '../models/nback_models.dart';

/// 実験フロー制御
/// 6分構成の実験ブロックを管理
class ExperimentFlowController {
  // フェーズの定義
  static const Duration baselineDuration = Duration(seconds: 60);
  static const Duration syncPhaseDuration = Duration(seconds: 120);
  static const Duration challengePhaseDuration = Duration(seconds: 60);
  static const Duration stabilityObservationDuration = Duration(seconds: 30);
  
  // 状態管理
  ExperimentPhase _currentPhase = ExperimentPhase.notStarted;
  Timer? _phaseTimer;
  DateTime? _phaseStartTime;
  DateTime? _experimentStartTime;
  
  // コールバック
  final void Function(ExperimentPhase)? onPhaseChanged;
  final void Function(Duration)? onPhaseProgress;
  final void Function()? onBlockCompleted;
  final void Function(String)? onInstruction;
  
  // 条件管理
  final ExperimentConditionManager conditionManager;
  
  // 現在のブロック情報
  int _currentBlockNumber = 0;
  int _totalBlocks = 0;
  
  ExperimentFlowController({
    required this.conditionManager,
    this.onPhaseChanged,
    this.onPhaseProgress,
    this.onBlockCompleted,
    this.onInstruction,
  });
  
  /// 実験を開始
  void startExperiment({required int totalBlocks}) {
    _totalBlocks = totalBlocks;
    _currentBlockNumber = 0;
    _experimentStartTime = DateTime.now();
    startNextBlock();
  }
  
  /// 次のブロックを開始
  void startNextBlock() {
    if (_currentBlockNumber >= _totalBlocks) {
      _completeExperiment();
      return;
    }
    
    _currentBlockNumber++;
    _startPhase(ExperimentPhase.baseline);
  }
  
  /// フェーズを開始
  void _startPhase(ExperimentPhase phase) {
    _currentPhase = phase;
    _phaseStartTime = DateTime.now();
    onPhaseChanged?.call(phase);
    
    // フェーズごとの指示を表示
    _showPhaseInstruction(phase);
    
    // タイマーを設定
    final duration = _getPhaseDuration(phase);
    _phaseTimer?.cancel();
    
    if (duration != null) {
      _phaseTimer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) => _updatePhaseProgress(timer, duration),
      );
      
      // フェーズ終了時の処理
      Timer(duration, () => _onPhaseCompleted());
    }
  }
  
  /// フェーズの進行状況を更新
  void _updatePhaseProgress(Timer timer, Duration totalDuration) {
    if (_phaseStartTime == null) return;
    
    final elapsed = DateTime.now().difference(_phaseStartTime!);
    final remaining = totalDuration - elapsed;
    
    if (remaining.isNegative) {
      timer.cancel();
      return;
    }
    
    onPhaseProgress?.call(remaining);
  }
  
  /// フェーズ完了時の処理
  void _onPhaseCompleted() {
    _phaseTimer?.cancel();
    
    switch (_currentPhase) {
      case ExperimentPhase.baseline:
        _startPhase(ExperimentPhase.syncPhase);
        break;
      case ExperimentPhase.syncPhase:
        _startPhase(ExperimentPhase.challengePhase1);
        break;
      case ExperimentPhase.challengePhase1:
        _startPhase(ExperimentPhase.challengePhase2);
        break;
      case ExperimentPhase.challengePhase2:
        _startPhase(ExperimentPhase.stabilityObservation);
        break;
      case ExperimentPhase.stabilityObservation:
        _completeBlock();
        break;
      case ExperimentPhase.rest:
        startNextBlock();
        break;
      default:
        break;
    }
  }
  
  /// ブロック完了
  void _completeBlock() {
    onBlockCompleted?.call();
    
    // 休憩が必要かチェック
    if (conditionManager.isRestNeeded() && _currentBlockNumber < _totalBlocks) {
      final restDuration = Duration(seconds: conditionManager.getRecommendedRestDuration());
      _startRestPhase(restDuration);
    } else if (conditionManager.moveToNextCondition()) {
      // 次の条件に進む
      startNextBlock();
    } else {
      // 実験完了
      _completeExperiment();
    }
  }
  
  /// 休憩フェーズを開始
  void _startRestPhase(Duration duration) {
    _currentPhase = ExperimentPhase.rest;
    _phaseStartTime = DateTime.now();
    onPhaseChanged?.call(ExperimentPhase.rest);
    
    onInstruction?.call(
      '休憩時間です。\n'
      '${duration.inMinutes}分間休憩してください。\n'
      '準備ができたら次のブロックを開始します。'
    );
    
    // 休憩タイマー
    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updatePhaseProgress(timer, duration),
    );
    
    Timer(duration, () => _onPhaseCompleted());
  }
  
  /// 実験完了
  void _completeExperiment() {
    _currentPhase = ExperimentPhase.completed;
    _phaseTimer?.cancel();
    onPhaseChanged?.call(ExperimentPhase.completed);
    onInstruction?.call('実験が完了しました。お疲れ様でした。');
  }
  
  /// フェーズの所要時間を取得
  Duration? _getPhaseDuration(ExperimentPhase phase) {
    switch (phase) {
      case ExperimentPhase.baseline:
        return baselineDuration;
      case ExperimentPhase.syncPhase:
        return syncPhaseDuration;
      case ExperimentPhase.challengePhase1:
      case ExperimentPhase.challengePhase2:
        return challengePhaseDuration;
      case ExperimentPhase.stabilityObservation:
        return stabilityObservationDuration;
      case ExperimentPhase.rest:
        return Duration(seconds: conditionManager.getRecommendedRestDuration());
      default:
        return null;
    }
  }
  
  /// フェーズごとの指示を表示
  void _showPhaseInstruction(ExperimentPhase phase) {
    final condition = conditionManager.getCurrentCondition();
    final conditionDesc = ExperimentConditionManager.getConditionDescription(condition);
    
    String instruction;
    switch (phase) {
      case ExperimentPhase.baseline:
        instruction = 'ベースライン測定\n\n'
            '自由に歩行してください（60秒間）。\n'
            'メトロノームは鳴りません。';
        break;
      case ExperimentPhase.syncPhase:
        instruction = '同期フェーズ\n\n'
            'メトロノームのリズムに合わせて歩いてください（120秒間）。\n'
            '現在の条件: $conditionDesc';
        break;
      case ExperimentPhase.challengePhase1:
        instruction = 'チャレンジフェーズ 1/2\n\n'
            'メトロノームのテンポが変化します。\n'
            'できるだけリズムに合わせて歩いてください（60秒間）。';
        if (condition.cognitiveLoad != CognitiveLoad.none) {
          instruction += '\n\n同時に${condition.cognitiveLoad.displayName}を行ってください。';
        }
        break;
      case ExperimentPhase.challengePhase2:
        instruction = 'チャレンジフェーズ 2/2\n\n'
            '引き続きメトロノームに合わせて歩いてください（60秒間）。';
        if (condition.cognitiveLoad != CognitiveLoad.none) {
          instruction += '\n\n${condition.cognitiveLoad.displayName}も続けてください。';
        }
        break;
      case ExperimentPhase.stabilityObservation:
        instruction = '安定観察期間\n\n'
            'そのまま歩き続けてください（30秒間）。\n'
            '歩行の安定性を観察しています。';
        break;
      default:
        instruction = '';
    }
    
    if (instruction.isNotEmpty) {
      onInstruction?.call(instruction);
    }
  }
  
  /// 現在の状態を取得
  ExperimentFlowState get currentState => ExperimentFlowState(
    currentPhase: _currentPhase,
    currentBlock: _currentBlockNumber,
    totalBlocks: _totalBlocks,
    phaseStartTime: _phaseStartTime,
    experimentStartTime: _experimentStartTime,
    currentCondition: conditionManager.getCurrentCondition(),
  );
  
  /// フェーズをスキップ（デバッグ用）
  void skipPhase() {
    _onPhaseCompleted();
  }
  
  /// 実験を中断
  void abortExperiment() {
    _phaseTimer?.cancel();
    _currentPhase = ExperimentPhase.aborted;
    onPhaseChanged?.call(ExperimentPhase.aborted);
    onInstruction?.call('実験が中断されました。');
  }
  
  /// リソースの解放
  void dispose() {
    _phaseTimer?.cancel();
  }
}

/// 実験フェーズ
enum ExperimentPhase {
  notStarted,
  baseline,
  syncPhase,
  challengePhase1,
  challengePhase2,
  stabilityObservation,
  rest,
  completed,
  aborted,
}

/// 実験フローの状態
class ExperimentFlowState {
  final ExperimentPhase currentPhase;
  final int currentBlock;
  final int totalBlocks;
  final DateTime? phaseStartTime;
  final DateTime? experimentStartTime;
  final ExperimentCondition currentCondition;
  
  ExperimentFlowState({
    required this.currentPhase,
    required this.currentBlock,
    required this.totalBlocks,
    this.phaseStartTime,
    this.experimentStartTime,
    required this.currentCondition,
  });
  
  Duration? get phaseElapsed {
    if (phaseStartTime == null) return null;
    return DateTime.now().difference(phaseStartTime!);
  }
  
  Duration? get totalElapsed {
    if (experimentStartTime == null) return null;
    return DateTime.now().difference(experimentStartTime!);
  }
  
  String get progressText => 'ブロック $currentBlock / $totalBlocks';
}

// ExperimentPhaseの拡張
extension ExperimentPhaseExtension on ExperimentPhase {
  String get displayName {
    switch (this) {
      case ExperimentPhase.notStarted:
        return '未開始';
      case ExperimentPhase.baseline:
        return 'ベースライン';
      case ExperimentPhase.syncPhase:
        return '同期フェーズ';
      case ExperimentPhase.challengePhase1:
        return 'チャレンジ 1';
      case ExperimentPhase.challengePhase2:
        return 'チャレンジ 2';
      case ExperimentPhase.stabilityObservation:
        return '安定観察';
      case ExperimentPhase.rest:
        return '休憩';
      case ExperimentPhase.completed:
        return '完了';
      case ExperimentPhase.aborted:
        return '中断';
    }
  }
  
  Color get phaseColor {
    switch (this) {
      case ExperimentPhase.baseline:
        return const Color(0xFF4CAF50);
      case ExperimentPhase.syncPhase:
        return const Color(0xFF2196F3);
      case ExperimentPhase.challengePhase1:
      case ExperimentPhase.challengePhase2:
        return const Color(0xFFFF9800);
      case ExperimentPhase.stabilityObservation:
        return const Color(0xFF9C27B0);
      case ExperimentPhase.rest:
        return const Color(0xFF607D8B);
      default:
        return const Color(0xFF757575);
    }
  }
}