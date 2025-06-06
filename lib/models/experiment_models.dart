import 'package:flutter/material.dart';

/// 実験条件を表すクラス
class ExperimentCondition {
  final String id;
  final String name;
  final bool useMetronome;
  final bool explicitInstruction;
  final String description;
  final bool useAdaptiveControl; // 個別対応機能の使用フラグ

  const ExperimentCondition({
    required this.id,
    required this.name,
    required this.useMetronome,
    required this.explicitInstruction,
    required this.description,
    this.useAdaptiveControl = false, // デフォルトはfalse
  });

  /// 事前定義された実験条件
  static const ExperimentCondition conditionA = ExperimentCondition(
    id: 'A',
    name: '無意識誘導条件',
    useMetronome: true,
    explicitInstruction: false,
    description: '指示なし・音のみ提示。「自然に歩いてください」',
  );

  static const ExperimentCondition conditionB = ExperimentCondition(
    id: 'B',
    name: '意識的誘導条件',
    useMetronome: true,
    explicitInstruction: true,
    description: '「音に合わせて歩くよう」指示',
  );

  static const ExperimentCondition conditionC = ExperimentCondition(
    id: 'C',
    name: 'コントロール条件',
    useMetronome: false,
    explicitInstruction: false,
    description: '音なし（無音）',
  );

  static const List<ExperimentCondition> allConditions = [
    conditionA,
    conditionB,
    conditionC,
  ];
}

/// 実験フェーズを定義する列挙型
enum AdvancedExperimentPhase {
  preparation, // 準備・キャリブレーション
  baseline, // ベースライン測定
  adaptation, // 適応フェーズ
  induction, // 誘導フェーズ
  postEffect, // 後効果測定
  evaluation // 事後評価
}

/// 誘導バリエーションを定義する列挙型
enum InductionVariation {
  increasing, // ベースラインから+20%まで増加
  decreasing // ベースラインから-20%まで減少
}

/// 実験タイプを定義する列挙型
enum ExperimentType {
  traditional, // 従来の順序固定実験
  randomOrder, // ランダム順序実験（音への反応研究用）
}

/// ランダム実験のフェーズタイプ
enum RandomPhaseType {
  freeWalk, // 自由歩行
  pitchKeep, // 現状歩行ピッチキープ
  pitchIncrease, // 歩行ピッチ上昇
}

/// ランダム実験フェーズの情報
class RandomPhaseInfo {
  final RandomPhaseType type;
  final String name;
  final String description;
  final Duration duration;
  final double? targetSpmMultiplier; // ベースラインに対する倍率

  const RandomPhaseInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.duration,
    this.targetSpmMultiplier,
  });
}

/// 実験フェーズの詳細情報を表すクラス
class ExperimentPhaseInfo {
  final AdvancedExperimentPhase phase;
  final String name;
  final String englishName;
  final String description;
  final IconData icon;
  final Color color;
  final Duration defaultDuration;
  final bool requiresMetronome;

  const ExperimentPhaseInfo({
    required this.phase,
    required this.name,
    required this.englishName,
    required this.description,
    required this.icon,
    required this.color,
    required this.defaultDuration,
    this.requiresMetronome = false,
  });

  /// 事前定義されたフェーズ情報
  static final Map<AdvancedExperimentPhase, ExperimentPhaseInfo> phaseInfo = {
    AdvancedExperimentPhase.preparation: const ExperimentPhaseInfo(
      phase: AdvancedExperimentPhase.preparation,
      name: '準備・キャリブレーション',
      englishName: 'Preparation',
      description: 'センサーの準備と実験説明',
      icon: Icons.settings,
      color: Colors.grey,
      defaultDuration: Duration(minutes: 5),
      requiresMetronome: false,
    ),
    AdvancedExperimentPhase.baseline: const ExperimentPhaseInfo(
      phase: AdvancedExperimentPhase.baseline,
      name: 'ベースライン測定',
      englishName: 'Baseline Measurement',
      description: '自由に歩いてください。通常のペースで歩行してください。',
      icon: Icons.directions_walk,
      color: Colors.blue,
      defaultDuration: Duration(minutes: 5),
      requiresMetronome: false,
    ),
    AdvancedExperimentPhase.adaptation: const ExperimentPhaseInfo(
      phase: AdvancedExperimentPhase.adaptation,
      name: '適応フェーズ',
      englishName: 'Adaptation Phase',
      description: '歩行を継続してください。',
      icon: Icons.sync,
      color: Colors.green,
      defaultDuration: Duration(minutes: 2),
      requiresMetronome: true,
    ),
    AdvancedExperimentPhase.induction: const ExperimentPhaseInfo(
      phase: AdvancedExperimentPhase.induction,
      name: '誘導フェーズ',
      englishName: 'Induction Phase',
      description: '歩行を継続してください。',
      icon: Icons.trending_up,
      color: Colors.orange,
      defaultDuration: Duration(minutes: 10),
      requiresMetronome: true,
    ),
    AdvancedExperimentPhase.postEffect: const ExperimentPhaseInfo(
      phase: AdvancedExperimentPhase.postEffect,
      name: '後効果測定',
      englishName: 'Post-Effect Measurement',
      description: '自由に歩いてください。',
      icon: Icons.assessment,
      color: Colors.purple,
      defaultDuration: Duration(minutes: 5),
      requiresMetronome: false,
    ),
    AdvancedExperimentPhase.evaluation: const ExperimentPhaseInfo(
      phase: AdvancedExperimentPhase.evaluation,
      name: '事後評価',
      englishName: 'Evaluation',
      description: 'アンケートに回答してください。',
      icon: Icons.assignment,
      color: Colors.indigo,
      defaultDuration: Duration(minutes: 2),
      requiresMetronome: false,
    ),
  };
}

/// 実験セッションを表すクラス
class ExperimentSession {
  final String id;
  final ExperimentCondition condition;
  final DateTime startTime;
  final String subjectId;
  final Map<String, dynamic> subjectData; // 年齢、性別、運動習慣など
  final InductionVariation inductionVariation;
  final Map<AdvancedExperimentPhase, Duration> phaseDurations;
  final ExperimentType experimentType;

  /// 誘導フェーズでのテンポ変化割合(1ステップあたり)
  final double inductionStepPercent;

  /// 誘導フェーズのステップ数
  final int inductionStepCount;

  /// ランダム実験用のフェーズリスト
  List<RandomPhaseInfo>? randomPhaseSequence;
  int currentRandomPhaseIndex = 0;

  AdvancedExperimentPhase currentPhase;
  DateTime? currentPhaseStartTime;
  double baselineSpm = 0.0;
  double targetSpm = 0.0;
  int stepCount = 0;
  double followRate = 0.0;
  int adaptationSeconds = 0;
  List<Map<String, dynamic>> timeSeriesData = [];

  /// 歩行安定性メトリクス
  double currentCV = 0.0; // 変動係数
  double currentSymmetry = 1.0; // 左右対称性

  /// 反応時間追跡
  DateTime? lastTempoChangeTime;
  Duration? responseTime;

  ExperimentSession({
    required this.id,
    required this.condition,
    required this.startTime,
    required this.subjectId,
    this.subjectData = const {},
    this.inductionVariation = InductionVariation.increasing,
    this.inductionStepPercent = 0.05,
    this.inductionStepCount = 4,
    this.experimentType = ExperimentType.traditional,
    Map<AdvancedExperimentPhase, Duration>? customPhaseDurations,
    this.currentPhase = AdvancedExperimentPhase.preparation,
    this.randomPhaseSequence,
  }) : phaseDurations = customPhaseDurations ??
            {
              AdvancedExperimentPhase.preparation: ExperimentPhaseInfo
                  .phaseInfo[AdvancedExperimentPhase.preparation]!
                  .defaultDuration,
              AdvancedExperimentPhase.baseline: ExperimentPhaseInfo
                  .phaseInfo[AdvancedExperimentPhase.baseline]!.defaultDuration,
              AdvancedExperimentPhase.adaptation: ExperimentPhaseInfo
                  .phaseInfo[AdvancedExperimentPhase.adaptation]!
                  .defaultDuration,
              AdvancedExperimentPhase.induction: ExperimentPhaseInfo
                  .phaseInfo[AdvancedExperimentPhase.induction]!
                  .defaultDuration,
              AdvancedExperimentPhase.postEffect: ExperimentPhaseInfo
                  .phaseInfo[AdvancedExperimentPhase.postEffect]!
                  .defaultDuration,
              AdvancedExperimentPhase.evaluation: ExperimentPhaseInfo
                  .phaseInfo[AdvancedExperimentPhase.evaluation]!
                  .defaultDuration,
            } {
    currentPhaseStartTime = DateTime.now();
  }

  /// 次のフェーズに進む
  void advanceToNextPhase() {
    const phases = AdvancedExperimentPhase.values;
    final currentIndex = phases.indexOf(currentPhase);

    if (currentIndex < phases.length - 1) {
      currentPhase = phases[currentIndex + 1];
      currentPhaseStartTime = DateTime.now();
    }
  }

  /// 現在のフェーズの残り時間を秒で取得
  int getRemainingSeconds() {
    if (currentPhaseStartTime == null) return 0;

    final phaseDuration = phaseDurations[currentPhase]?.inSeconds ?? 0;
    final elapsedSeconds =
        DateTime.now().difference(currentPhaseStartTime!).inSeconds;

    return phaseDuration - elapsedSeconds;
  }

  /// 現在のフェーズの経過時間を秒で取得
  int getElapsedSeconds() {
    if (currentPhaseStartTime == null) return 0;
    return DateTime.now().difference(currentPhaseStartTime!).inSeconds;
  }

  /// 現在のフェーズの進捗率を取得 (0.0 - 1.0)
  double getPhaseProgress() {
    if (currentPhaseStartTime == null) return 0.0;

    final phaseDuration = phaseDurations[currentPhase]?.inSeconds ?? 1;
    final elapsedSeconds =
        DateTime.now().difference(currentPhaseStartTime!).inSeconds;

    return elapsedSeconds / phaseDuration;
  }

  /// 現在のフェーズ情報を取得
  ExperimentPhaseInfo getPhaseInfo() {
    return ExperimentPhaseInfo.phaseInfo[currentPhase]!;
  }

  /// 誘導フェーズのテンポステップを計算
  List<double> getInductionTempoSteps() {
    if (baselineSpm <= 0) return [];

    final steps = <double>[];
    final stepCount = inductionStepCount;
    final stepPercent = inductionStepPercent;

    if (inductionVariation == InductionVariation.increasing) {
      for (int i = 1; i <= stepCount; i++) {
        steps.add(baselineSpm * (1 + stepPercent * i));
      }
    } else {
      for (int i = 1; i <= stepCount; i++) {
        steps.add(baselineSpm * (1 - stepPercent * i));
      }
    }

    return steps;
  }

  /// 時系列データを記録
  void recordTimeSeriesData({
    required double currentSpm,
    required double targetSpm,
    double? followRate,
    Map<String, dynamic>? additionalData,
  }) {
    final data = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'phase': getPhaseInfo().englishName,
      'elapsedSeconds': getElapsedSeconds(),
      'targetSPM': targetSpm,
      'currentSPM': currentSpm,
      'followRate': followRate,
      'condition': condition.id,
    };

    if (additionalData != null) {
      data.addAll(additionalData);
    }

    timeSeriesData.add(data);
  }

  /// 追従率を計算
  double calculateFollowRate(double targetSpm, double actualSpm) {
    if (targetSpm <= 0 || actualSpm <= 0) return 0.0;
    return (1.0 - (actualSpm - targetSpm).abs() / targetSpm) * 100.0;
  }

  /// ランダム実験の次のフェーズに進む
  void advanceToNextRandomPhase() {
    if (randomPhaseSequence == null ||
        currentRandomPhaseIndex >= randomPhaseSequence!.length - 1) {
      return;
    }

    currentRandomPhaseIndex++;
    currentPhaseStartTime = DateTime.now();
  }

  /// 現在のランダムフェーズを取得
  RandomPhaseInfo? getCurrentRandomPhase() {
    if (randomPhaseSequence == null ||
        currentRandomPhaseIndex >= randomPhaseSequence!.length) {
      return null;
    }
    return randomPhaseSequence![currentRandomPhaseIndex];
  }

  /// テンポ変更時の反応時間を記録開始
  void startResponseTimeTracking() {
    lastTempoChangeTime = DateTime.now();
    responseTime = null;
  }

  /// 反応完了時の時間を記録
  void recordResponseTime() {
    if (lastTempoChangeTime != null && responseTime == null) {
      responseTime = DateTime.now().difference(lastTempoChangeTime!);
    }
  }

  /// 歩行安定性メトリクスを更新
  void updateStabilityMetrics(double cv, double symmetry) {
    currentCV = cv;
    currentSymmetry = symmetry;
  }
}

/// 主観評価回答を表すクラス
class SubjectiveEvaluation {
  final int fatigueLevel; // 疲労度 (1-5)
  final int concentrationLevel; // 集中度 (1-5)
  final int awarenessLevel; // 音楽の聴こえ方・意識度 (1-5)
  final String comments; // 自由記述

  SubjectiveEvaluation({
    required this.fatigueLevel,
    required this.concentrationLevel,
    required this.awarenessLevel,
    this.comments = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'fatigueLevel': fatigueLevel,
      'concentrationLevel': concentrationLevel,
      'awarenessLevel': awarenessLevel,
      'comments': comments,
    };
  }
}
