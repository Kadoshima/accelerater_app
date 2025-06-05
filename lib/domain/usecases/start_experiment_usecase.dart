import '../../core/utils/result.dart';
import '../../models/experiment_models.dart';
import '../repositories/experiment_repository.dart';
import '../repositories/metronome_repository.dart';
import '../repositories/gait_analysis_repository.dart';

/// 実験開始のユースケース
class StartExperimentUseCase {
  final ExperimentRepository _experimentRepository;
  final MetronomeRepository _metronomeRepository;
  final GaitAnalysisRepository _gaitAnalysisRepository;

  StartExperimentUseCase({
    required ExperimentRepository experimentRepository,
    required MetronomeRepository metronomeRepository,
    required GaitAnalysisRepository gaitAnalysisRepository,
  })  : _experimentRepository = experimentRepository,
        _metronomeRepository = metronomeRepository,
        _gaitAnalysisRepository = gaitAnalysisRepository;

  Future<Result<ExperimentSession>> execute({
    required ExperimentCondition condition,
    required String subjectId,
    Map<String, dynamic>? subjectData,
    InductionVariation inductionVariation = InductionVariation.increasing,
    Map<AdvancedExperimentPhase, Duration>? customPhaseDurations,
    double inductionStepPercent = 0.05,
    int inductionStepCount = 4,
  }) async {
    // 既存の実験を停止
    await _experimentRepository.stopExperiment();
    
    // メトロノームを初期化
    final metronomeResult = await _metronomeRepository.initialize();
    
    return await metronomeResult.fold(
      (error) async => Results.failure<ExperimentSession>(error),
      (_) async {
        // 歩行解析をリセット
        _gaitAnalysisRepository.reset();
        
        // 新しい実験を開始
        return await _experimentRepository.startExperiment(
          condition: condition,
          subjectId: subjectId,
          subjectData: subjectData,
          inductionVariation: inductionVariation,
          customPhaseDurations: customPhaseDurations,
          inductionStepPercent: inductionStepPercent,
          inductionStepCount: inductionStepCount,
        );
      },
    );
  }
}