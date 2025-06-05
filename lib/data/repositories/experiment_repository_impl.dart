import 'dart:async';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/result.dart';
import '../../core/utils/logger_service.dart';
import '../../core/errors/app_exceptions.dart';
import '../../domain/repositories/experiment_repository.dart';
import '../../domain/repositories/metronome_repository.dart';
import '../../domain/repositories/gait_analysis_repository.dart';
import '../../models/experiment_models.dart';

/// 実験管理リポジトリの実装
class ExperimentRepositoryImpl implements ExperimentRepository {
  final MetronomeRepository _metronomeRepository;
  final GaitAnalysisRepository _gaitAnalysisRepository;
  
  ExperimentSession? _currentSession;
  Timer? _phaseTimer;
  Timer? _dataRecordingTimer;
  Timer? _adaptationStabilityTimer;
  
  final StreamController<ExperimentSession?> _sessionController = StreamController<ExperimentSession?>.broadcast();
  final StreamController<AdvancedExperimentPhase> _phaseController = StreamController<AdvancedExperimentPhase>.broadcast();
  
  // 実験パラメータ
  final int _requiredStableSeconds = 30;
  final double _stabilityThreshold = 5.0;
  int _stableSeconds = 0;
  bool _isStable = false;
  
  // 誘導フェーズ管理
  List<double> _inductionTempoSteps = [];
  int _currentInductionStepIndex = 0;

  ExperimentRepositoryImpl({
    required MetronomeRepository metronomeRepository,
    required GaitAnalysisRepository gaitAnalysisRepository,
  })  : _metronomeRepository = metronomeRepository,
        _gaitAnalysisRepository = gaitAnalysisRepository;

  @override
  Future<Result<ExperimentSession>> startExperiment({
    required ExperimentCondition condition,
    required String subjectId,
    Map<String, dynamic>? subjectData,
    InductionVariation inductionVariation = InductionVariation.increasing,
    Map<AdvancedExperimentPhase, Duration>? customPhaseDurations,
    double inductionStepPercent = 0.05,
    int inductionStepCount = 4,
  }) async {
    return Results.tryAsync(() async {
      // 前のセッションがあれば停止
      await stopExperiment();
      
      // 新しいセッションを作成
      final sessionId = 'session_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
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
      
      _sessionController.add(_currentSession);
      logger.info('Experiment started: ${condition.name}');
      
      // 準備フェーズから開始
      _startCurrentPhase();
      
      // データ記録タイマーを開始（2秒ごと）
      _dataRecordingTimer?.cancel();
      _dataRecordingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _recordTimeSeriesData();
      });
      
      return _currentSession!;
    }, onError: (error, stackTrace) {
      logger.error('Failed to start experiment', error, stackTrace);
      return ExperimentException(
        message: 'Failed to start experiment',
        originalError: error,
      );
    });
  }

  @override
  Future<Result<void>> stopExperiment() async {
    return Results.tryAsync(() async {
      // タイマーをキャンセル
      _phaseTimer?.cancel();
      _phaseTimer = null;
      
      _dataRecordingTimer?.cancel();
      _dataRecordingTimer = null;
      
      _adaptationStabilityTimer?.cancel();
      _adaptationStabilityTimer = null;
      
      // メトロノームを停止
      if (_metronomeRepository.isPlaying) {
        await _metronomeRepository.stop();
      }
      
      // データを保存
      if (_currentSession != null) {
        await saveSessionData(_currentSession!);
        logger.info('Experiment stopped: ${_currentSession!.condition.name}');
      }
      
      _currentSession = null;
      _stableSeconds = 0;
      _isStable = false;
      _sessionController.add(null);
    });
  }

  @override
  ExperimentSession? get currentSession => _currentSession;

  @override
  Stream<ExperimentSession?> get sessionStream => _sessionController.stream;

  @override
  Stream<AdvancedExperimentPhase> get phaseStream => _phaseController.stream;

  @override
  Future<Result<void>> recordTimeSeriesData({
    required double currentSpm,
    required double targetSpm,
    required double followRate,
    Map<String, dynamic>? additionalData,
  }) async {
    return Results.trySync(() {
      if (_currentSession == null) return;
      
      _currentSession!.recordTimeSeriesData(
        currentSpm: currentSpm,
        targetSpm: targetSpm,
        followRate: followRate,
        additionalData: additionalData,
      );
    });
  }

  @override
  Future<Result<void>> advanceToNextPhase() async {
    return Results.tryAsync(() async {
      _phaseTimer?.cancel();
      _handlePhaseCompletion();
    });
  }

  @override
  Future<Result<void>> setSubjectiveEvaluation(SubjectiveEvaluation evaluation) async {
    return Results.trySync(() {
      if (_currentSession == null) {
        throw const ExperimentException(
          message: 'No active experiment session',
          code: 'NO_ACTIVE_SESSION',
        );
      }
      
      _currentSession!.subjectData['subjective_evaluation'] = evaluation.toJson();
      logger.info('Subjective evaluation recorded');
    });
  }

  @override
  Future<Result<void>> saveSessionData(ExperimentSession session) async {
    return Results.tryAsync(() async {
      final directory = await getApplicationDocumentsDirectory();
      
      // フォルダを作成（存在しない場合）
      final folderPath = '${directory.path}/experiment_data';
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      
      // ファイル名を生成
      final fileName = 'experiment_${session.condition.id}_${session.subjectId}_${DateFormat('yyyyMMdd_HHmmss').format(session.startTime)}.csv';
      final filePath = '$folderPath/$fileName';
      
      // CSVデータを作成
      final csvData = _createCsvData(session);
      
      // CSVファイルに書き込み
      final file = File(filePath);
      final csvString = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csvString);
      
      logger.info('Experiment data saved: $fileName');
    }, onError: (error, stackTrace) {
      logger.error('Failed to save experiment data', error, stackTrace);
      return StorageException(
        message: 'Failed to save experiment data',
        originalError: error,
      );
    });
  }

  @override
  Future<Result<List<ExperimentSession>>> getStoredSessions() async {
    // TODO: Implement loading stored sessions
    return Results.success([]);
  }

  @override
  Future<Result<ExperimentSession>> getSessionById(String sessionId) async {
    // TODO: Implement loading specific session
    return Results.failure(
      const StorageException(
        message: 'Not implemented',
        code: 'NOT_IMPLEMENTED',
      ),
    );
  }

  @override
  Future<Result<String>> exportSessionData(String sessionId, ExportFormat format) async {
    // TODO: Implement export functionality
    return Results.failure(
      const StorageException(
        message: 'Not implemented',
        code: 'NOT_IMPLEMENTED',
      ),
    );
  }

  // Private methods
  void _startCurrentPhase() {
    if (_currentSession == null) return;
    
    final session = _currentSession!;
    final phase = session.currentPhase;
    
    _phaseController.add(phase);
    
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

  void _handlePhaseCompletion() {
    if (_currentSession == null) return;
    
    final session = _currentSession!;
    final currentPhase = session.currentPhase;
    
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
      default:
        break;
    }
    
    // 次のフェーズへ進む
    session.advanceToNextPhase();
    _startCurrentPhase();
  }

  void _handlePreparationPhase() {
    // 準備フェーズの処理
  }

  void _handleBaselinePhase() {
    if (_currentSession == null) return;
    
    // メトロノームが再生中なら停止
    if (_metronomeRepository.isPlaying) {
      _metronomeRepository.stop();
    }
    
    // 歩行データ収集を開始
    _adaptationStabilityTimer?.cancel();
    _adaptationStabilityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateBaselineStability();
    });
  }

  void _finalizeBaselinePhase() {
    if (_currentSession == null) return;
    
    // 過去30秒間の平均歩行ピッチを計算
    final history = _gaitAnalysisRepository.spmHistory;
    final recentSpmValues = history.length > 30 
        ? history.skip(history.length - 30).toList()
        : history;
    if (recentSpmValues.isNotEmpty) {
      final averageSpm = recentSpmValues.reduce((a, b) => a + b) / recentSpmValues.length;
      // 5の倍数に丸める
      final roundedSpm = (averageSpm / 5).round() * 5.0;
      
      _currentSession!.baselineSpm = roundedSpm;
      _currentSession!.targetSpm = roundedSpm;
    }
    
    _adaptationStabilityTimer?.cancel();
  }

  void _handleAdaptationPhase() {
    if (_currentSession == null) return;
    
    final session = _currentSession!;
    
    // 条件に応じてメトロノームを開始
    if (session.condition.useMetronome && session.baselineSpm > 0) {
      _metronomeRepository.start(bpm: session.baselineSpm);
    }
    
    // 安定性カウンターをリセット
    _stableSeconds = 0;
    _isStable = false;
    
    // 安定性監視タイマーを開始
    _adaptationStabilityTimer?.cancel();
    _adaptationStabilityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateAdaptationStability();
    });
  }

  void _finalizeAdaptationPhase() {
    _adaptationStabilityTimer?.cancel();
    
    if (_currentSession == null) return;
    
    // 誘導フェーズ用のテンポステップを計算
    _inductionTempoSteps = _currentSession!.getInductionTempoSteps();
    _currentInductionStepIndex = 0;
  }

  void _handleInductionPhase() {
    if (_currentSession == null || _inductionTempoSteps.isEmpty) return;
    
    final session = _currentSession!;
    
    // 最初のテンポステップを設定
    _currentInductionStepIndex = 0;
    final firstTempoStep = _inductionTempoSteps[0];
    session.targetSpm = firstTempoStep;
    
    // 条件に応じてメトロノームを調整
    if (session.condition.useMetronome) {
      _metronomeRepository.changeTempo(firstTempoStep);
    }
    
    // 安定性カウンターをリセット
    _stableSeconds = 0;
    _isStable = false;
    
    // 安定性監視タイマーを開始
    _adaptationStabilityTimer?.cancel();
    _adaptationStabilityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateInductionStability();
    });
  }

  void _finalizeInductionPhase() {
    _adaptationStabilityTimer?.cancel();
  }

  void _handlePostEffectPhase() {
    if (_currentSession == null) return;
    
    // メトロノームを停止
    if (_metronomeRepository.isPlaying) {
      _metronomeRepository.stop();
    }
  }

  void _handleEvaluationPhase() {
    // 評価フェーズの処理
  }

  void _updateBaselineStability() {
    // ベースラインフェーズの安定性更新
  }

  void _updateAdaptationStability() {
    if (_currentSession == null) return;
    
    final session = _currentSession!;
    final currentSpm = _gaitAnalysisRepository.currentSpm;
    
    if (currentSpm <= 0 || session.baselineSpm <= 0) return;
    
    // 現在のピッチとベースラインピッチの差を計算
    final difference = (currentSpm - session.baselineSpm).abs();
    
    // 差が閾値以内なら安定とみなす
    if (difference <= _stabilityThreshold) {
      _stableSeconds++;
      if (_stableSeconds >= _requiredStableSeconds && !_isStable) {
        _isStable = true;
      }
    } else {
      _stableSeconds = 0;
      _isStable = false;
    }
    
    // セッションの状態を更新
    session.adaptationSeconds = _stableSeconds;
    session.followRate = session.calculateFollowRate(session.baselineSpm, currentSpm);
  }

  void _updateInductionStability() {
    if (_currentSession == null || _inductionTempoSteps.isEmpty) return;
    
    final session = _currentSession!;
    final currentSpm = _gaitAnalysisRepository.currentSpm;
    
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
    session.followRate = session.calculateFollowRate(currentTargetSpm, currentSpm);
  }

  void _moveToNextInductionStep() {
    if (_currentSession == null || _inductionTempoSteps.isEmpty) return;
    
    _currentInductionStepIndex++;
    
    // すべてのステップが完了した場合
    if (_currentInductionStepIndex >= _inductionTempoSteps.length) {
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
      _metronomeRepository.changeTempo(nextTempoStep);
    }
    
    // 安定性カウンターをリセット
    _stableSeconds = 0;
    _isStable = false;
  }

  void _recordTimeSeriesData() {
    if (_currentSession == null) return;
    
    final session = _currentSession!;
    
    // 現在のSPMを取得
    final currentSpm = _gaitAnalysisRepository.currentSpm;
    
    // 追加データを収集
    final additionalData = {
      'spmHistory': () {
        final history = _gaitAnalysisRepository.spmHistory;
        return List<double>.from(
          history.length > 10 
              ? history.skip(history.length - 10).toList()
              : history
        );
      }(),
      'stableSeconds': _stableSeconds,
      'isStable': _isStable,
      'reliability': _gaitAnalysisRepository.reliability,
      'stepCount': _gaitAnalysisRepository.stepCount,
      'isPlaying': _metronomeRepository.isPlaying,
      'currentTempo': _metronomeRepository.currentBpm,
      'inductionStepIndex': _currentInductionStepIndex,
    };
    
    // データを記録
    session.recordTimeSeriesData(
      currentSpm: currentSpm,
      targetSpm: session.targetSpm,
      followRate: session.followRate,
      additionalData: additionalData,
    );
  }

  List<List<dynamic>> _createCsvData(ExperimentSession session) {
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
    
    return csvData;
  }

  void dispose() {
    _phaseTimer?.cancel();
    _dataRecordingTimer?.cancel();
    _adaptationStabilityTimer?.cancel();
    _sessionController.close();
    _phaseController.close();
  }
}