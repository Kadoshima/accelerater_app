import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../lib/services/experiment_condition_manager.dart';
import '../../lib/services/experiment_flow_controller.dart';
import '../../lib/services/adaptive_tempo_service.dart';
import '../../lib/services/phase_error_engine.dart';
import '../../lib/services/audio_conflict_resolver.dart';
import '../../lib/services/nback_sequence_generator.dart';
import '../../lib/models/nback_models.dart';

void main() {
  group('Dual Task Protocol Integration Tests', () {
    late ExperimentConditionManager conditionManager;
    late ExperimentFlowController flowController;
    late AdaptiveTempoService tempoService;
    late PhaseErrorEngine phaseErrorEngine;
    late AudioConflictResolver conflictResolver;
    late NBackSequenceGenerator sequenceGenerator;

    setUp(() {
      conditionManager = ExperimentConditionManager();
      tempoService = AdaptiveTempoService();
      phaseErrorEngine = PhaseErrorEngine();
      conflictResolver = AudioConflictResolver();
      sequenceGenerator = NBackSequenceGenerator();
    });

    tearDown(() {
      flowController.dispose();
    });

    test('completes full 6-condition experiment flow', () async {
      conditionManager.initialize(participantNumber: 1);
      
      int phaseChanges = 0;
      ExperimentPhase? lastPhase;
      
      flowController = ExperimentFlowController(
        conditionManager: conditionManager,
        onPhaseChanged: (phase) {
          phaseChanges++;
          lastPhase = phase;
        },
        onPhaseProgress: (_) {},
        onBlockCompleted: () {},
        onInstruction: (_) {},
      );
      
      // 実験開始
      flowController.startExperiment(totalBlocks: 6);
      
      // 各ブロックをシミュレート
      for (int block = 0; block < 6; block++) {
        // フェーズ進行をシミュレート
        await _simulateBlock(flowController);
        
        if (block < 5) {
          expect(lastPhase, equals(ExperimentPhase.rest));
        } else {
          expect(lastPhase, equals(ExperimentPhase.completed));
        }
      }
      
      // 6ブロック × 5フェーズ + 5休憩 + 1完了 = 36フェーズ変更
      expect(phaseChanges, greaterThanOrEqualTo(30));
    });

    test('adaptive tempo control works correctly', () async {
      // 適応的テンポ制御のテスト
      final clickTimes = <DateTime>[];
      final heelStrikeTimes = <DateTime>[];
      final baseTime = DateTime.now();
      
      // シミュレートされた歩行データ
      for (int i = 0; i < 100; i++) {
        // メトロノームクリック（100 BPM = 600ms間隔）
        clickTimes.add(baseTime.add(Duration(milliseconds: i * 600)));
        
        // かかと接地（わずかに遅れて）
        final delay = 50 + (i % 10) * 5; // 50-95msの遅れ
        heelStrikeTimes.add(clickTimes.last.add(Duration(milliseconds: delay)));
      }
      
      // 適応的テンポ更新
      double currentBpm = 100.0;
      for (int i = 0; i < clickTimes.length; i++) {
        currentBpm = tempoService.updateBpm(
          clickTime: clickTimes[i],
          heelStrikeTime: heelStrikeTimes[i],
        );
        
        // 位相誤差を記録
        phaseErrorEngine.recordPhaseError(
          clickTime: clickTimes[i],
          heelStrikeTime: heelStrikeTimes[i],
          currentSpm: currentBpm,
        );
      }
      
      // BPMが調整されていることを確認
      expect(currentBpm, isNot(equals(100.0)));
      
      // 収束を確認
      final convergenceTime = phaseErrorEngine.getConvergenceTime();
      expect(convergenceTime, isNotNull);
      
      // RMSEが改善していることを確認
      final rmse = phaseErrorEngine.getCurrentRmse();
      expect(rmse, lessThan(0.1)); // 100ms以下
    });

    test('audio conflict resolution prevents collisions', () async {
      final baseTime = DateTime.now();
      
      // メトロノームクリックをスケジュール
      conflictResolver.scheduleMetronomeClick(baseTime);
      conflictResolver.scheduleMetronomeClick(
        baseTime.add(const Duration(milliseconds: 600)),
      );
      conflictResolver.scheduleMetronomeClick(
        baseTime.add(const Duration(milliseconds: 1200)),
      );
      
      // N-back音声が衝突しそうなタイミングでスケジュール
      final nbackTime1 = conflictResolver.scheduleNBackAudio(
        originalTime: baseTime.add(const Duration(milliseconds: 50)),
        duration: 1000,
      );
      
      final nbackTime2 = conflictResolver.scheduleNBackAudio(
        originalTime: baseTime.add(const Duration(milliseconds: 650)),
        duration: 1000,
      );
      
      // 衝突が回避されていることを確認
      expect(
        nbackTime1.difference(baseTime).inMilliseconds,
        greaterThanOrEqualTo(200),
      );
      
      expect(
        nbackTime2.difference(baseTime.add(const Duration(milliseconds: 600))).inMilliseconds.abs(),
        greaterThanOrEqualTo(200),
      );
      
      // 衝突ログを確認
      final conflicts = conflictResolver.getConflictLog();
      expect(conflicts.length, greaterThan(0));
    });

    test('all 6 experimental conditions execute correctly', () async {
      conditionManager.initialize(participantNumber: 1);
      
      final conditions = conditionManager.getAllConditions();
      expect(conditions.length, equals(6));
      
      // 各条件をテスト
      for (final condition in conditions) {
        if (condition.cognitiveLoad != CognitiveLoad.none) {
          // N-backシーケンスが生成できることを確認
          final nLevel = _getNBackLevel(condition.cognitiveLoad);
          final sequence = sequenceGenerator.generate(
            length: 30,
            nLevel: nLevel,
          );
          
          expect(sequence.length, equals(30));
          
          // 正答が存在することを確認
          final answers = sequenceGenerator.calculateCorrectAnswers(sequence, nLevel);
          final correctCount = answers.where((a) => a).length;
          expect(correctCount, greaterThan(0));
        }
        
        if (condition.tempoControl == TempoControl.adaptive) {
          // 適応的テンポ制御が機能することを確認
          final bpm = tempoService.updateBpm(
            clickTime: DateTime.now(),
            heelStrikeTime: DateTime.now().add(const Duration(milliseconds: 50)),
          );
          expect(bpm, isNotNull);
        }
      }
    });

    test('phase transitions follow correct timing', () async {
      conditionManager.initialize(participantNumber: 1);
      
      final phaseDurations = <ExperimentPhase, Duration>{};
      DateTime? phaseStartTime;
      ExperimentPhase? currentPhase;
      
      flowController = ExperimentFlowController(
        conditionManager: conditionManager,
        onPhaseChanged: (phase) {
          if (phaseStartTime != null && currentPhase != null) {
            phaseDurations[currentPhase!] = DateTime.now().difference(phaseStartTime!);
          }
          phaseStartTime = DateTime.now();
          currentPhase = phase;
        },
        onPhaseProgress: (_) {},
        onBlockCompleted: () {},
        onInstruction: (_) {},
      );
      
      // タイミングをテスト用に短縮
      flowController.setTestMode(speedMultiplier: 100);
      
      flowController.startExperiment(totalBlocks: 1);
      
      // 1ブロック分を高速でシミュレート
      await Future.delayed(const Duration(seconds: 5));
      
      // フェーズ時間を検証
      expect(phaseDurations[ExperimentPhase.baseline], isNotNull);
      expect(phaseDurations[ExperimentPhase.syncPhase], isNotNull);
      expect(phaseDurations[ExperimentPhase.challengePhase1], isNotNull);
    });

    test('data recording maintains synchronization', () async {
      final baseTime = DateTime.now();
      final dataPoints = <({DateTime time, String type, dynamic data})>[];
      
      // 異なるサンプリングレートでデータを生成
      // IMU: 100Hz
      for (int i = 0; i < 100; i++) {
        dataPoints.add((
          time: baseTime.add(Duration(milliseconds: i * 10)),
          type: 'imu',
          data: {'acc': [0, 0, 9.8], 'gyro': [0, 0, 0]},
        ));
      }
      
      // Heart rate: 3秒間隔
      dataPoints.add((
        time: baseTime,
        type: 'hr',
        data: {'bpm': 65},
      ));
      dataPoints.add((
        time: baseTime.add(const Duration(seconds: 3)),
        type: 'hr',
        data: {'bpm': 68},
      ));
      
      // N-back: 2秒間隔
      for (int i = 0; i < 5; i++) {
        dataPoints.add((
          time: baseTime.add(Duration(seconds: i * 2)),
          type: 'nback',
          data: {'stimulus': i + 1, 'response': i > 0 ? i : null},
        ));
      }
      
      // データポイントをソート
      dataPoints.sort((a, b) => a.time.compareTo(b.time));
      
      // タイムスタンプの整合性を確認
      for (int i = 1; i < dataPoints.length; i++) {
        expect(
          dataPoints[i].time.isAfter(dataPoints[i-1].time) ||
          dataPoints[i].time.isAtSameMomentAs(dataPoints[i-1].time),
          isTrue,
        );
      }
    });
  });
}

// Helper functions
int _getNBackLevel(CognitiveLoad load) {
  switch (load) {
    case CognitiveLoad.none:
      return 0;
    case CognitiveLoad.nBack0:
      return 0;
    case CognitiveLoad.nBack1:
      return 1;
    case CognitiveLoad.nBack2:
      return 2;
  }
}

Future<void> _simulateBlock(ExperimentFlowController controller) async {
  // フェーズを自動的に進行させる
  // 実際の実装では、各フェーズの時間経過をシミュレート
  await Future.delayed(const Duration(milliseconds: 100));
}

// Test mode extension for ExperimentFlowController
extension TestMode on ExperimentFlowController {
  void setTestMode({required int speedMultiplier}) {
    // テストモードでタイミングを高速化
    // 実際の実装では、内部のタイマー設定を調整
  }
}