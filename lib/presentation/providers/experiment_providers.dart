import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/experiment_repository.dart';
import '../../domain/usecases/start_experiment_usecase.dart';
import '../../data/repositories/experiment_repository_impl.dart';
import '../../models/experiment_models.dart';
import 'gait_analysis_providers.dart';
import 'metronome_providers.dart';

/// 実験リポジトリのプロバイダー
final experimentRepositoryProvider = Provider<ExperimentRepository>((ref) {
  final metronomeRepository = ref.watch(metronomeRepositoryProvider);
  final gaitAnalysisRepository = ref.watch(gaitAnalysisRepositoryProvider);
  
  return ExperimentRepositoryImpl(
    metronomeRepository: metronomeRepository,
    gaitAnalysisRepository: gaitAnalysisRepository,
  );
});

/// 実験開始ユースケースのプロバイダー
final startExperimentUseCaseProvider = Provider<StartExperimentUseCase>((ref) {
  final experimentRepository = ref.watch(experimentRepositoryProvider);
  final metronomeRepository = ref.watch(metronomeRepositoryProvider);
  final gaitAnalysisRepository = ref.watch(gaitAnalysisRepositoryProvider);
  
  return StartExperimentUseCase(
    experimentRepository: experimentRepository,
    metronomeRepository: metronomeRepository,
    gaitAnalysisRepository: gaitAnalysisRepository,
  );
});

/// 現在の実験セッションのプロバイダー
final currentExperimentSessionProvider = StateProvider<ExperimentSession?>((ref) => null);

/// 実験フェーズのプロバイダー
final currentExperimentPhaseProvider = StateProvider<AdvancedExperimentPhase?>((ref) => null);

/// 実験の進行状態を管理するプロバイダー
final experimentStateProvider = StateNotifierProvider<ExperimentStateNotifier, ExperimentState>((ref) {
  final repository = ref.watch(experimentRepositoryProvider);
  final startExperimentUseCase = ref.watch(startExperimentUseCaseProvider);
  final metronomeController = ref.watch(metronomeControllerProvider);
  
  return ExperimentStateNotifier(
    repository: repository,
    startExperimentUseCase: startExperimentUseCase,
    metronomeController: metronomeController,
    ref: ref,
  );
});

/// 実験の状態
class ExperimentState {
  final bool isRunning;
  final ExperimentSession? currentSession;
  final AdvancedExperimentPhase? currentPhase;
  final Duration? elapsedTime;
  final Duration? phaseElapsedTime;
  final double? targetBpm;
  final double? currentSpm;
  final int? stepCount;
  final bool isStable;
  final int stableSeconds;

  const ExperimentState({
    this.isRunning = false,
    this.currentSession,
    this.currentPhase,
    this.elapsedTime,
    this.phaseElapsedTime,
    this.targetBpm,
    this.currentSpm,
    this.stepCount,
    this.isStable = false,
    this.stableSeconds = 0,
  });

  ExperimentState copyWith({
    bool? isRunning,
    ExperimentSession? currentSession,
    AdvancedExperimentPhase? currentPhase,
    Duration? elapsedTime,
    Duration? phaseElapsedTime,
    double? targetBpm,
    double? currentSpm,
    int? stepCount,
    bool? isStable,
    int? stableSeconds,
  }) {
    return ExperimentState(
      isRunning: isRunning ?? this.isRunning,
      currentSession: currentSession ?? this.currentSession,
      currentPhase: currentPhase ?? this.currentPhase,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      phaseElapsedTime: phaseElapsedTime ?? this.phaseElapsedTime,
      targetBpm: targetBpm ?? this.targetBpm,
      currentSpm: currentSpm ?? this.currentSpm,
      stepCount: stepCount ?? this.stepCount,
      isStable: isStable ?? this.isStable,
      stableSeconds: stableSeconds ?? this.stableSeconds,
    );
  }
}

/// 実験状態を管理するNotifier
class ExperimentStateNotifier extends StateNotifier<ExperimentState> {
  final ExperimentRepository _repository;
  final StartExperimentUseCase _startExperimentUseCase;
  final MetronomeController _metronomeController;
  final Ref _ref;
  StreamSubscription<ExperimentSession?>? _sessionSubscription;
  StreamSubscription<AdvancedExperimentPhase>? _phaseSubscription;

  ExperimentStateNotifier({
    required ExperimentRepository repository,
    required StartExperimentUseCase startExperimentUseCase,
    required MetronomeController metronomeController,
    required Ref ref,
  })  : _repository = repository,
        _startExperimentUseCase = startExperimentUseCase,
        _metronomeController = metronomeController,
        _ref = ref,
        super(const ExperimentState()) {
    // セッションとフェーズの変更を監視
    _sessionSubscription = _repository.sessionStream.listen((session) {
      if (session != null) {
        state = state.copyWith(
          isRunning: true,
          currentSession: session,
        );
      }
    });
    
    _phaseSubscription = _repository.phaseStream.listen((phase) {
      updatePhase(phase);
    });
  }

  Future<void> startExperiment({
    required ExperimentCondition condition,
    required String subjectId,
    Map<String, dynamic>? subjectData,
  }) async {
    final result = await _startExperimentUseCase.execute(
      condition: condition,
      subjectId: subjectId,
      subjectData: subjectData,
    );
    
    result.fold(
      (error) {
        // エラー処理
      },
      (session) {
        state = state.copyWith(
          isRunning: true,
          currentSession: session,
          currentPhase: AdvancedExperimentPhase.preparation,
          elapsedTime: Duration.zero,
          phaseElapsedTime: Duration.zero,
        );
      },
    );

    // メトロノームを初期化
    await _metronomeController.initialize();
  }

  void updatePhase(AdvancedExperimentPhase phase) {
    _ref.read(currentExperimentPhaseProvider.notifier).state = phase;
    
    state = state.copyWith(
      currentPhase: phase,
      phaseElapsedTime: Duration.zero,
    );
  }

  void updateMetrics({
    double? currentSpm,
    int? stepCount,
    bool? isStable,
    int? stableSeconds,
  }) {
    state = state.copyWith(
      currentSpm: currentSpm,
      stepCount: stepCount,
      isStable: isStable,
      stableSeconds: stableSeconds,
    );
  }

  Future<void> startMetronome(double bpm) async {
    await _metronomeController.setBpm(bpm);
    await _metronomeController.start();
    
    state = state.copyWith(targetBpm: bpm);
  }

  Future<void> stopMetronome() async {
    await _metronomeController.stop();
    
    state = state.copyWith(targetBpm: null);
  }

  Future<void> adjustMetronomeBpm(double bpm) async {
    await _metronomeController.setBpm(bpm);
    
    state = state.copyWith(targetBpm: bpm);
  }

  void recordData() {
    // The ExperimentRepository handles data recording internally
    // via its timer in _recordTimeSeriesData method
  }

  Future<void> endExperiment() async {
    await _repository.stopExperiment();
    _ref.read(currentExperimentSessionProvider.notifier).state = null;
    _ref.read(currentExperimentPhaseProvider.notifier).state = null;
    
    state = const ExperimentState();
  }
  
  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _phaseSubscription?.cancel();
    super.dispose();
  }

  void updateElapsedTime(Duration elapsed, Duration phaseElapsed) {
    state = state.copyWith(
      elapsedTime: elapsed,
      phaseElapsedTime: phaseElapsed,
    );
  }
}