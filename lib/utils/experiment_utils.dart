import 'dart:math';
import '../models/experiment_models.dart';

/// 実験に関するユーティリティ関数
class ExperimentUtils {
  /// ランダムな実験フェーズシーケンスを生成
  static List<RandomPhaseInfo> generateRandomPhaseSequence({
    required int phaseCount,
    Duration? minPhaseDuration,
    Duration? maxPhaseDuration,
    double baselineSpm = 100.0,
  }) {
    final random = Random();
    final phases = <RandomPhaseInfo>[];

    // デフォルトのフェーズ時間設定
    minPhaseDuration ??= const Duration(minutes: 1);
    maxPhaseDuration ??= const Duration(minutes: 3);

    // 各フェーズタイプの最小出現回数を確保
    final phaseTypes = <RandomPhaseType>[];

    // 各タイプを最低1回ずつ追加
    phaseTypes.addAll(RandomPhaseType.values);

    // 残りのフェーズをランダムに追加
    while (phaseTypes.length < phaseCount) {
      phaseTypes.add(RandomPhaseType
          .values[random.nextInt(RandomPhaseType.values.length)]);
    }

    // シャッフル
    phaseTypes.shuffle(random);

    // フェーズ情報を生成
    for (int i = 0; i < phaseTypes.length; i++) {
      final type = phaseTypes[i];

      // ランダムな時間長さを生成（30秒単位）
      final minSeconds = minPhaseDuration.inSeconds;
      final maxSeconds = maxPhaseDuration.inSeconds;
      final durationSeconds = minSeconds +
          (random.nextInt((maxSeconds - minSeconds) ~/ 30) * 30) +
          30;

      final duration = Duration(seconds: durationSeconds);

      // フェーズ情報を作成
      switch (type) {
        case RandomPhaseType.freeWalk:
          phases.add(RandomPhaseInfo(
            type: type,
            name: '自由歩行フェーズ ${i + 1}',
            description: '自由なペースで歩行してください',
            duration: duration,
          ));
          break;

        case RandomPhaseType.pitchKeep:
          phases.add(RandomPhaseInfo(
            type: type,
            name: 'ピッチ維持フェーズ ${i + 1}',
            description: 'ベースラインのペースを維持してください',
            duration: duration,
            targetSpmMultiplier: 1.0,
          ));
          break;

        case RandomPhaseType.pitchIncrease:
          // 5%〜20%の増加率をランダムに設定
          final increasePercent = 5 + random.nextInt(16); // 5-20%
          final multiplier = 1.0 + (increasePercent / 100.0);

          phases.add(RandomPhaseInfo(
            type: type,
            name: 'ピッチ上昇フェーズ ${i + 1}',
            description: 'ペースを$increasePercent%上げてください',
            duration: duration,
            targetSpmMultiplier: multiplier,
          ));
          break;
      }
    }

    return phases;
  }

  /// 実験条件をランダムに生成（反応研究用）
  static ExperimentCondition createReactionStudyCondition({
    bool useAdaptiveControl = false,
  }) {
    return ExperimentCondition(
      id: 'RS${DateTime.now().millisecondsSinceEpoch}',
      name: useAdaptiveControl ? '適応制御あり反応研究' : '適応制御なし反応研究',
      useMetronome: true,
      explicitInstruction: false,
      description: '音への反応を調査する実験条件',
      useAdaptiveControl: useAdaptiveControl,
    );
  }

  /// ランダムな時間長さの配列を生成
  static List<Duration> generateRandomDurations({
    required int count,
    required Duration min,
    required Duration max,
    int stepSeconds = 30,
  }) {
    final random = Random();
    final durations = <Duration>[];

    final minSeconds = min.inSeconds;
    final maxSeconds = max.inSeconds;
    final steps = (maxSeconds - minSeconds) ~/ stepSeconds;

    for (int i = 0; i < count; i++) {
      final randomSteps = random.nextInt(steps + 1);
      final seconds = minSeconds + (randomSteps * stepSeconds);
      durations.add(Duration(seconds: seconds));
    }

    return durations;
  }
}
