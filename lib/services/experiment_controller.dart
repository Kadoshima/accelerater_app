import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';

import '../models/experiment_models.dart';
import '../utils/gait_analysis_service.dart';
import 'metronome.dart';
import 'native_metronome.dart';

/// 実験の進行とデータ収集を管理するコントローラクラス
class ExperimentController {
  /// 現在の実験セッション
  ExperimentSession? _currentSession;
  ExperimentSession? get currentSession => _currentSession;

  /// 現在の誘導フェーズでのテンポステップ
  List<double> _inductionTempoSteps = [];
  int _currentInductionStepIndex = 0;

  /// 実験結果のコールバック
  final void Function(String message)? onMessage;
  final void Function(ExperimentSession session)? onSessionComplete;
  final void Function(ExperimentSession session, AdvancedExperimentPhase phase)?
      onPhaseChange;
  final void Function(ExperimentSession session, Map<String, dynamic> data)?
      onDataRecorded;

  /// タイマー
  Timer? _phaseTimer;
  Timer? _dataRecordingTimer;
  Timer? _adaptationStabilityTimer;

  /// 依存サービス
  final GaitAnalysisService _gaitAnalysisService;
  final Metronome _metronome;
  final NativeMetronome _nativeMetronome;
  bool _useNativeMetronome = true;

  /// 安定性追跡パラメータ
  List<double> _recentSpmValues = [];
  int _stableSeconds = 0;
  bool _isStable = false;
  final int _requiredStableSeconds = 30; // 安定とみなす秒数
  final double _stabilityThreshold = 5.0; // 安定性の閾値（BPM差）

  /// 最新の検出SPM
  double _currentSpm = 0.0;
  
  /// 最新の心拍数
  int _currentHeartRate = 0;

  ExperimentController({
    required GaitAnalysisService gaitAnalysisService,
    required Metronome metronome,
    required NativeMetronome nativeMetronome,
    bool useNativeMetronome = true,
    this.onMessage,
    this.onSessionComplete,
    this.onPhaseChange,
    this.onDataRecorded,
  })  : _gaitAnalysisService = gaitAnalysisService,
        _metronome = metronome,
        _nativeMetronome = nativeMetronome,
        _useNativeMetronome = useNativeMetronome;

  /// メトロノームの再生状態を取得
  bool get isPlaying =>
      _useNativeMetronome ? _nativeMetronome.isPlaying : _metronome.isPlaying;

  /// 現在のテンポを取得
  double get currentTempo =>
      _useNativeMetronome ? _nativeMetronome.currentBpm : _metronome.currentBpm;
      
  /// 心拍数を更新
  void updateHeartRate(int heartRate) {
    _currentHeartRate = heartRate;
  }

  /// 実験セッションを開始
  Future<void> startExperiment({
    required ExperimentCondition condition,
    required String subjectId,
    Map<String, dynamic>? subjectData,
    InductionVariation inductionVariation = InductionVariation.increasing,
    Map<AdvancedExperimentPhase, Duration>? customPhaseDurations,
    double inductionStepPercent = 0.05,
    int inductionStepCount = 4,
  }) async {
    // 前のセッションがあれば停止
    await stopExperiment();

    // 新しいセッションを作成
    final sessionId =
        'session_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
    _currentSession = ExperimentSession(
      id: sessionId,
      condition: condition,
      startTime: DateTime.now(),
      subjectId: subjectId,
      subjectData: subjectData ?? {},
      inductionVariation: inductionVariation,
      customPhaseDurations: customPhaseDurations,
      inductionStepPercent: inductionStepPercent,
      inductionStepCount: inductionStepCount,
    );

    _sendMessage('実験を開始しました: ${condition.name}');

    // 準備フェーズから開始
    _startCurrentPhase();

    // データ記録タイマーを開始（1秒ごと = 1Hz）
    _dataRecordingTimer?.cancel();
    _dataRecordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordTimeSeriesData();
    });
  }

  /// 実験を停止
  Future<void> stopExperiment() async {
    // タイマーをキャンセル
    _phaseTimer?.cancel();
    _phaseTimer = null;

    _dataRecordingTimer?.cancel();
    _dataRecordingTimer = null;

    _adaptationStabilityTimer?.cancel();
    _adaptationStabilityTimer = null;

    // メトロノームを停止
    if (isPlaying) {
      if (_useNativeMetronome) {
        await _nativeMetronome.stop();
      } else {
        await _metronome.stop();
      }
    }

    // データを保存
    if (_currentSession != null) {
      await _saveSessionData(_currentSession!);
      onSessionComplete?.call(_currentSession!);
      _sendMessage('実験を終了しました: ${_currentSession!.condition.name}');
    }

    _currentSession = null;
    _recentSpmValues.clear();
    _stableSeconds = 0;
    _isStable = false;
  }

  /// 実験をリセット（データ保存なし）
  Future<void> resetExperiment() async {
    // タイマーをキャンセル
    _phaseTimer?.cancel();
    _phaseTimer = null;

    _dataRecordingTimer?.cancel();
    _dataRecordingTimer = null;

    _adaptationStabilityTimer?.cancel();
    _adaptationStabilityTimer = null;

    // メトロノームを停止
    if (isPlaying) {
      if (_useNativeMetronome) {
        await _nativeMetronome.stop();
      } else {
        await _metronome.stop();
      }
    }

    // データ保存せずにリセット
    _currentSession = null;
    _recentSpmValues.clear();
    _stableSeconds = 0;
    _isStable = false;
    _currentSpm = 0.0;
    _inductionTempoSteps.clear();
    _currentInductionStepIndex = 0;
    
    // 歩行解析サービスもリセット
    _gaitAnalysisService.reset();

    _sendMessage('実験をリセットしました');
  }

  /// 現在のフェーズを開始
  void _startCurrentPhase() {
    if (_currentSession == null) return;

    final session = _currentSession!;
    final phase = session.currentPhase;
    final phaseInfo = session.getPhaseInfo();

    _sendMessage('${phaseInfo.name}を開始しました');
    onPhaseChange?.call(session, phase);

    // フェーズタイマーを開始
    _phaseTimer?.cancel();
    _phaseTimer = Timer(session.phaseDurations[phase]!, () {
      _handlePhaseCompletion();
    });

    // フェーズ固有の初期化
    switch (phase) {
      case AdvancedExperimentPhase.preparation:
        _handlePreparationPhase();
        break;
      case AdvancedExperimentPhase.baseline:
        _handleBaselinePhase();
        break;
      case AdvancedExperimentPhase.adaptation:
        _handleAdaptationPhase();
        break;
      case AdvancedExperimentPhase.induction:
        _handleInductionPhase();
        break;
      case AdvancedExperimentPhase.postEffect:
        _handlePostEffectPhase();
        break;
      case AdvancedExperimentPhase.evaluation:
        _handleEvaluationPhase();
        break;
    }
  }

  /// フェーズが完了した時の処理
  void _handlePhaseCompletion() {
    if (_currentSession == null) return;

    final session = _currentSession!;
    final currentPhase = session.currentPhase;
    final phaseInfo = session.getPhaseInfo();

    _sendMessage('${phaseInfo.name}が完了しました');

    // フェーズ終了時の特別な処理
    switch (currentPhase) {
      case AdvancedExperimentPhase.baseline:
        _finalizeBaselinePhase();
        break;
      case AdvancedExperimentPhase.adaptation:
        _finalizeAdaptationPhase();
        break;
      case AdvancedExperimentPhase.induction:
        _finalizeInductionPhase();
        break;
      case AdvancedExperimentPhase.postEffect:
        _finalizePostEffectPhase();
        break;
      case AdvancedExperimentPhase.evaluation:
        _finalizeEvaluationPhase();
        break;
      default:
        break;
    }

    // 次のフェーズへ進む
    session.advanceToNextPhase();
    _startCurrentPhase();
  }

  /// 準備フェーズの処理
  void _handlePreparationPhase() {
    // キャリブレーションや説明を行う
    // 実際の操作はUIで行うため、ここでは特に何もしない
  }

  /// ベースラインフェーズの処理
  void _handleBaselinePhase() {
    if (_currentSession == null) return;

    // メトロノームが再生中なら停止
    if (isPlaying) {
      if (_useNativeMetronome) {
        _nativeMetronome.stop();
      } else {
        _metronome.stop();
      }
    }

    // 歩行データ収集を開始
    _recentSpmValues.clear();

    // 安定性監視タイマーを開始（1秒ごと）
    _adaptationStabilityTimer?.cancel();
    _adaptationStabilityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateSpmStability();
    });
  }

  /// ベースラインフェーズの終了処理
  void _finalizeBaselinePhase() {
    if (_currentSession == null) return;

    // 過去30秒間の平均歩行ピッチを計算
    if (_recentSpmValues.isNotEmpty) {
      final averageSpm =
          _recentSpmValues.reduce((a, b) => a + b) / _recentSpmValues.length;
      // 5の倍数に丸める
      final roundedSpm = (averageSpm / 5).round() * 5.0;

      _currentSession!.baselineSpm = roundedSpm;
      _currentSession!.targetSpm = roundedSpm;

      _sendMessage('ベースライン歩行ピッチ: ${roundedSpm.toStringAsFixed(1)} SPM');
    }

    _adaptationStabilityTimer?.cancel();
  }

  /// 適応フェーズの処理
  void _handleAdaptationPhase() {
    if (_currentSession == null) return;

    final session = _currentSession!;

    // 条件に応じてメトロノームを開始
    if (session.condition.useMetronome && session.baselineSpm > 0) {
      _startMetronome(session.baselineSpm);

      if (session.condition.explicitInstruction) {
        _sendMessage(
            '音に合わせて歩いてください。BPM: ${session.baselineSpm.toStringAsFixed(1)}');
      } else {
        _sendMessage('自然に歩き続けてください。');
      }
    } else {
      _sendMessage('自然に歩き続けてください。');
    }

    // 安定性カウンターをリセット
    _stableSeconds = 0;
    _isStable = false;

    // 安定性監視タイマーを開始（1秒ごと）
    _adaptationStabilityTimer?.cancel();
    _adaptationStabilityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateAdaptationStability();
    });
  }

  /// 適応フェーズの終了処理
  void _finalizeAdaptationPhase() {
    _adaptationStabilityTimer?.cancel();

    if (_currentSession == null) return;

    // 誘導フェーズ用のテンポステップを計算
    _inductionTempoSteps = _currentSession!.getInductionTempoSteps();
    _currentInductionStepIndex = 0;
  }

  /// 誘導フェーズの処理
  void _handleInductionPhase() {
    if (_currentSession == null || _inductionTempoSteps.isEmpty) return;

    final session = _currentSession!;

    // 最初のテンポステップを設定
    _currentInductionStepIndex = 0;
    final firstTempoStep = _inductionTempoSteps[0];
    session.targetSpm = firstTempoStep;

    // 条件に応じてメトロノームを調整
    if (session.condition.useMetronome) {
      _changeMetronomeTempo(firstTempoStep);

      if (session.condition.explicitInstruction) {
        _sendMessage('音に合わせて歩いてください。BPM: ${firstTempoStep.toStringAsFixed(1)}');
      } else {
        _sendMessage('自然に歩き続けてください。');
      }
    } else {
      _sendMessage('自然に歩き続けてください。');
    }

    // 安定性カウンターをリセット
    _stableSeconds = 0;
    _isStable = false;

    // 安定性監視タイマーを開始（1秒ごと）
    _adaptationStabilityTimer?.cancel();
    _adaptationStabilityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateInductionStability();
    });
  }

  /// 誘導フェーズの終了処理
  void _finalizeInductionPhase() {
    _adaptationStabilityTimer?.cancel();
  }

  /// 後効果フェーズの処理
  void _handlePostEffectPhase() {
    if (_currentSession == null) return;

    // メトロノームを停止
    if (isPlaying) {
      if (_useNativeMetronome) {
        _nativeMetronome.stop();
      } else {
        _metronome.stop();
      }
    }

    _sendMessage('音が止まりました。自然に歩き続けてください。');

    // 歩行データ収集を継続
    _recentSpmValues.clear();
  }

  /// 後効果フェーズの終了処理
  void _finalizePostEffectPhase() {
    // 特に何もしない
  }

  /// 評価フェーズの処理
  void _handleEvaluationPhase() {
    _sendMessage('実験が完了しました。アンケートに回答してください。');
    // 実際のアンケート表示はUIで行う
  }

  /// 評価フェーズの終了処理
  void _finalizeEvaluationPhase() {
    // 実験全体の終了処理
    stopExperiment();
  }

  /// 現在のSPMの安定性を更新（ベースラインフェーズ用）
  void _updateSpmStability() {
    final currentSpm = _gaitAnalysisService.currentSpm;
    _currentSpm = currentSpm;

    if (currentSpm <= 0) return;

    // 最近のSPM値に追加
    _recentSpmValues.add(currentSpm);

    // 最大30秒分のデータを保持
    if (_recentSpmValues.length > 30) {
      _recentSpmValues.removeAt(0);
    }
  }

  /// 適応フェーズの安定性を更新
  void _updateAdaptationStability() {
    if (_currentSession == null) return;

    final session = _currentSession!;
    final currentSpm = _gaitAnalysisService.currentSpm;
    _currentSpm = currentSpm;

    if (currentSpm <= 0 || session.baselineSpm <= 0) return;

    // 現在のピッチとベースラインピッチの差を計算
    final difference = (currentSpm - session.baselineSpm).abs();

    // 差が閾値以内なら安定とみなす
    if (difference <= _stabilityThreshold) {
      _stableSeconds++;
      if (_stableSeconds >= _requiredStableSeconds && !_isStable) {
        _isStable = true;
        _sendMessage('歩行リズムが安定しました');
      }
    } else {
      _stableSeconds = 0;
      _isStable = false;
    }

    // セッションの状態を更新
    session.adaptationSeconds = _stableSeconds;
    session.followRate =
        session.calculateFollowRate(session.baselineSpm, currentSpm);
  }

  /// 誘導フェーズの安定性を更新
  void _updateInductionStability() {
    if (_currentSession == null || _inductionTempoSteps.isEmpty) return;

    final session = _currentSession!;
    final currentSpm = _gaitAnalysisService.currentSpm;
    _currentSpm = currentSpm;

    if (currentSpm <= 0) return;

    // 現在のテンポステップ
    final currentTargetSpm = _inductionTempoSteps[_currentInductionStepIndex];

    // 現在のピッチとターゲットピッチの差を計算
    final difference = (currentSpm - currentTargetSpm).abs();

    // 差が閾値以内なら安定とみなす
    if (difference <= _stabilityThreshold) {
      _stableSeconds++;
      if (_stableSeconds >= _requiredStableSeconds && !_isStable) {
        _isStable = true;
        _sendMessage('歩行リズムが安定しました');
      }

      // 2分（120秒）間安定していたら次のテンポステップへ
      if (_stableSeconds >= 120) {
        _moveToNextInductionStep();
      }
    } else {
      _stableSeconds = 0;
      _isStable = false;
    }

    // セッションの状態を更新
    session.adaptationSeconds = _stableSeconds;
    session.followRate =
        session.calculateFollowRate(currentTargetSpm, currentSpm);
  }

  /// 次の誘導ステップに進む
  void _moveToNextInductionStep() {
    if (_currentSession == null || _inductionTempoSteps.isEmpty) return;

    _currentInductionStepIndex++;

    // すべてのステップが完了した場合
    if (_currentInductionStepIndex >= _inductionTempoSteps.length) {
      _sendMessage('すべてのテンポステップが完了しました');

      // フェーズタイマーをキャンセルして強制的に次のフェーズへ
      _phaseTimer?.cancel();
      _handlePhaseCompletion();
      return;
    }

    // 次のテンポステップを設定
    final nextTempoStep = _inductionTempoSteps[_currentInductionStepIndex];
    _currentSession!.targetSpm = nextTempoStep;

    // メトロノームを調整
    if (_currentSession!.condition.useMetronome) {
      _changeMetronomeTempo(nextTempoStep);

      if (_currentSession!.condition.explicitInstruction) {
        _sendMessage(
            '音のテンポが変わりました。音に合わせて歩いてください。BPM: ${nextTempoStep.toStringAsFixed(1)}');
      } else {
        _sendMessage('歩行を継続してください');
      }
    }

    // 安定性カウンターをリセット
    _stableSeconds = 0;
    _isStable = false;
  }

  /// メトロノームを開始
  Future<void> _startMetronome(double tempo) async {
    try {
      if (_useNativeMetronome) {
        await _nativeMetronome.stop();
        await _nativeMetronome.changeTempo(tempo);
        await _nativeMetronome.start(bpm: tempo);
      } else {
        await _metronome.stop();
        await _metronome.changeTempo(tempo);
        await _metronome.start(bpm: tempo);
      }
    } catch (e) {
      _sendMessage('メトロノーム開始エラー: $e');

      // ネイティブメトロノームで失敗した場合はDartメトロノームを試す
      if (_useNativeMetronome) {
        _useNativeMetronome = false;
        await _metronome.stop();
        await _metronome.changeTempo(tempo);
        await _metronome.start(bpm: tempo);
      }
    }
  }

  /// メトロノームのテンポを変更
  Future<void> _changeMetronomeTempo(double tempo) async {
    try {
      if (_useNativeMetronome) {
        await _nativeMetronome.changeTempo(tempo);
      } else {
        await _metronome.changeTempo(tempo);
      }
    } catch (e) {
      _sendMessage('テンポ変更エラー: $e');

      // ネイティブメトロノームで失敗した場合はDartメトロノームを試す
      if (_useNativeMetronome) {
        _useNativeMetronome = false;
        await _metronome.changeTempo(tempo);
      }
    }
  }

  /// 時系列データを記録
  void _recordTimeSeriesData() {
    if (_currentSession == null) return;

    final session = _currentSession!;

    // 現在のSPMを取得
    final currentSpm = _gaitAnalysisService.currentSpm;
    _currentSpm = currentSpm;

    // 追加データを収集
    final additionalData = {
      'spmHistory': List<double>.from(_recentSpmValues),
      'stableSeconds': _stableSeconds,
      'isStable': _isStable,
      'reliability': _gaitAnalysisService.reliability,
      'stepCount': _gaitAnalysisService.stepCount,
      'isPlaying': isPlaying,
      'currentTempo': currentTempo,
      'inductionStepIndex': _currentInductionStepIndex,
      'currentHeartRate': _currentHeartRate,
    };

    // データを記録
    session.recordTimeSeriesData(
      currentSpm: currentSpm,
      targetSpm: session.targetSpm,
      followRate: session.followRate,
      additionalData: additionalData,
    );

    // コールバックを呼び出し
    onDataRecorded?.call(session, session.timeSeriesData.last);
  }

  /// セッションデータを保存
  Future<void> _saveSessionData(ExperimentSession session) async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      // フォルダを作成（存在しない場合）
      final folderPath = '${directory.path}/experiment_data';
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      // ファイル名を生成
      final fileName =
          'experiment_${session.condition.id}_${session.subjectId}_${DateFormat('yyyyMMdd_HHmmss').format(session.startTime)}.csv';
      final filePath = '${folderPath}/${fileName}';

      // CSVデータを作成
      final csvData = <List<dynamic>>[];

      // ヘッダー行（メタデータ）
      csvData.add(['# Experiment_Metadata']);
      csvData.add([
        'Subject_ID',
        'Condition',
        'Condition_Description',
        'Induction_Variation',
        'Start_Time',
        'Baseline_SPM',
        'Data_Points'
      ]);
      csvData.add([
        session.subjectId,
        session.condition.id,
        session.condition.description,
        session.inductionVariation.toString().split('.').last,
        DateFormat('yyyy-MM-dd HH:mm:ss').format(session.startTime),
        session.baselineSpm.toStringAsFixed(1),
        session.timeSeriesData.length
      ]);

      // 被験者データ
      if (session.subjectData.isNotEmpty) {
        csvData.add(['# Subject_Data']);
        final subjectDataRow = <dynamic>[];
        session.subjectData.forEach((key, value) {
          subjectDataRow.add('$key: $value');
        });
        csvData.add(subjectDataRow);
      }

      // データヘッダー
      csvData.add(['# Time_Series_Data']);
      csvData.add([
        'timestamp',
        'phase',
        'elapsed_seconds',
        'target_spm',
        'current_spm',
        'follow_rate',
        'is_stable',
        'stable_seconds',
        'is_playing',
        'reliability'
      ]);

      // データ行
      for (final data in session.timeSeriesData) {
        csvData.add([
          DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(
              DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)),
          data['phase'],
          data['elapsedSeconds'],
          data['targetSPM'],
          data['currentSPM'],
          data['followRate'] != null
              ? '${data['followRate'].toStringAsFixed(1)}%'
              : 'N/A',
          data['isStable'] ?? false,
          data['stableSeconds'] ?? 0,
          data['isPlaying'] ?? false,
          data['reliability'] != null
              ? '${(data['reliability'] * 100).toStringAsFixed(1)}%'
              : 'N/A'
        ]);
      }

      // CSVファイルに書き込み
      final file = File(filePath);
      final csvString = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csvString);

      _sendMessage('実験データを保存しました: $fileName');

      // TODO: クラウドへのアップロード処理があれば追加
    } catch (e) {
      _sendMessage('データ保存エラー: $e');
    }
  }

  /// メッセージを送信
  void _sendMessage(String message) {
    onMessage?.call(message);
    print('ExperimentController: $message');
  }

  /// リソースを解放
  void dispose() {
    stopExperiment();
  }

  /// 主観評価を設定
  void setSubjectiveEvaluation(SubjectiveEvaluation evaluation) {
    if (_currentSession == null) return;

    // 評価データをsessionに追加
    _currentSession!.subjectData['subjective_evaluation'] = evaluation.toJson();
    _sendMessage('主観評価が記録されました');
  }

  /// 実験を次のフェーズに手動で進める
  void advanceToNextPhase() {
    if (_currentSession == null) return;

    _phaseTimer?.cancel();
    _handlePhaseCompletion();
  }

  /// 現在のSPM値を取得
  double getCurrentSpm() {
    return _currentSpm;
  }

  /// 安定しているかどうかを取得
  bool isStable() {
    return _isStable;
  }

  /// 安定している秒数を取得
  int getStableSeconds() {
    return _stableSeconds;
  }
}
