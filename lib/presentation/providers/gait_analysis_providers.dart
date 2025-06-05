import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/gait_analysis_repository.dart' as domain;
import '../../data/repositories/gait_analysis_repository_impl.dart';
import '../../models/sensor_data.dart';

/// 歩行解析リポジトリのプロバイダー
final gaitAnalysisRepositoryProvider = Provider<domain.GaitAnalysisRepository>((ref) {
  return GaitAnalysisRepositoryImpl();
});

/// 現在のSPMを監視するプロバイダー
final currentSpmProvider = StateProvider<double>((ref) => 0.0);

/// 歩数カウントを監視するプロバイダー
final stepCountProvider = StateProvider<int>((ref) => 0);

/// 信頼性スコアを監視するプロバイダー
final reliabilityScoreProvider = StateProvider<double>((ref) => 0.0);

/// 静止状態を監視するプロバイダー
final isStaticProvider = StateProvider<bool>((ref) => true);

/// 歩行解析状態を管理するプロバイダー
final gaitAnalysisStateProvider = StateNotifierProvider<GaitAnalysisStateNotifier, GaitAnalysisState>((ref) {
  final repository = ref.watch(gaitAnalysisRepositoryProvider);
  return GaitAnalysisStateNotifier(repository, ref);
});

/// 歩行解析の状態
class GaitAnalysisState {
  final double currentSpm;
  final int stepCount;
  final double reliability;
  final bool isStatic;
  final List<double> recentSpmValues;
  final DateTime? lastUpdate;

  const GaitAnalysisState({
    this.currentSpm = 0.0,
    this.stepCount = 0,
    this.reliability = 0.0,
    this.isStatic = true,
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

/// 歩行解析状態を管理するNotifier
class GaitAnalysisStateNotifier extends StateNotifier<GaitAnalysisState> {
  final domain.GaitAnalysisRepository _repository;
  final Ref _ref;
  StreamSubscription<domain.GaitAnalysisState>? _subscription;
  
  GaitAnalysisStateNotifier(this._repository, this._ref) : super(const GaitAnalysisState()) {
    // リポジトリの状態を監視
    _subscription = _repository.stateStream.listen((repoState) {
      state = GaitAnalysisState(
        currentSpm: repoState.currentSpm,
        stepCount: repoState.stepCount,
        reliability: repoState.reliability,
        isStatic: repoState.isStatic,
        recentSpmValues: repoState.recentSpmValues,
        lastUpdate: repoState.lastUpdate,
      );
      _updateProviders(state);
    });
    
    // 初期状態を設定
    _updateState();
  }
  
  void addSensorData(M5SensorData data) {
    _repository.addSensorData(data);
  }
  
  void reset() {
    _repository.reset();
    state = const GaitAnalysisState();
  }
  
  void _updateState() {
    state = state.copyWith(
      currentSpm: _repository.currentSpm,
      stepCount: _repository.stepCount,
      reliability: _repository.reliability,
      isStatic: _repository.isStatic,
      recentSpmValues: _getRecentSpmValues(),
      lastUpdate: DateTime.now(),
    );
    
    _updateProviders(state);
  }
  
  void _updateProviders(GaitAnalysisState state) {
    // 個別のプロバイダーを更新
    _ref.read(currentSpmProvider.notifier).state = state.currentSpm;
    _ref.read(stepCountProvider.notifier).state = state.stepCount;
    _ref.read(reliabilityScoreProvider.notifier).state = state.reliability;
    _ref.read(isStaticProvider.notifier).state = state.isStatic;
  }
  
  List<double> _getRecentSpmValues() {
    final history = _repository.spmHistory;
    return history.length > 30
        ? history.skip(history.length - 30).toList()
        : history;
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}