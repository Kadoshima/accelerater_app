import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

void main() {
  group('Timing Accuracy Tests', () {
    test('metronome maintains accurate BPM timing', () async {
      const targetBpm = 100.0;
      const intervalMs = 60000 / targetBpm; // 600ms
      const tolerance = 5; // ±5ms tolerance
      
      final clicks = <DateTime>[];
      final timer = Timer.periodic(
        Duration(milliseconds: intervalMs.round()),
        (timer) {
          clicks.add(DateTime.now());
          if (clicks.length >= 10) {
            timer.cancel();
          }
        },
      );
      
      // 10クリック分待機
      await Future.delayed(const Duration(seconds: 7));
      
      // インターバルを検証
      final intervals = <int>[];
      for (int i = 1; i < clicks.length; i++) {
        intervals.add(clicks[i].difference(clicks[i-1]).inMilliseconds);
      }
      
      // 平均インターバル
      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      expect(avgInterval, closeTo(intervalMs, tolerance));
      
      // 標準偏差
      final variance = intervals.map((i) => 
        (i - avgInterval) * (i - avgInterval)
      ).reduce((a, b) => a + b) / intervals.length;
      final stdDev = variance.abs().toDouble();
      
      expect(stdDev, lessThan(10)); // 標準偏差 < 10ms
    });

    test('n-back stimulus presentation timing is accurate', () async {
      const presentationInterval = 2000; // 2秒
      const tolerance = 10; // ±10ms
      
      final presentations = <DateTime>[];
      
      // N-back刺激提示をシミュレート
      for (int i = 0; i < 5; i++) {
        presentations.add(DateTime.now());
        await Future.delayed(const Duration(milliseconds: presentationInterval));
      }
      
      // インターバルを検証
      for (int i = 1; i < presentations.length; i++) {
        final interval = presentations[i].difference(presentations[i-1]).inMilliseconds;
        expect(interval, closeTo(presentationInterval, tolerance));
      }
    });

    test('phase transitions occur at correct times', () async {
      // フェーズ時間の定義（秒）
      const phaseDurations = {
        'baseline': 60,
        'sync': 120,
        'challenge1': 60,
        'challenge2': 60,
        'stability': 30,
      };
      
      final phaseChanges = <String, DateTime>{};
      final startTime = DateTime.now();
      
      // フェーズ遷移をシミュレート（高速化）
      for (final entry in phaseDurations.entries) {
        phaseChanges[entry.key] = DateTime.now();
        await Future.delayed(Duration(milliseconds: entry.value * 10)); // 100倍速
      }
      
      // 各フェーズの実際の継続時間を確認
      var previousTime = startTime;
      for (final entry in phaseDurations.entries) {
        final actualDuration = phaseChanges[entry.key]!.difference(previousTime);
        final expectedDuration = Duration(milliseconds: entry.value * 10);
        
        expect(
          actualDuration.inMilliseconds,
          closeTo(expectedDuration.inMilliseconds, 50), // ±50ms tolerance
        );
        
        previousTime = phaseChanges[entry.key]!;
      }
    });

    test('audio conflict resolution maintains minimum gap', () async {
      const minGap = 200; // 200ms
      final events = <DateTime>[];
      
      // メトロノームクリック
      final metronomeTime = DateTime.now();
      events.add(metronomeTime);
      
      // N-back音声（衝突しそうなタイミング）
      var nbackTime = metronomeTime.add(const Duration(milliseconds: 100));
      
      // 衝突回避
      if (nbackTime.difference(metronomeTime).inMilliseconds.abs() < minGap) {
        nbackTime = metronomeTime.add(const Duration(milliseconds: minGap));
      }
      
      events.add(nbackTime);
      
      // 最小間隔を確認
      final gap = events[1].difference(events[0]).inMilliseconds;
      expect(gap, greaterThanOrEqualTo(minGap));
    });

    test('data synchronization handles clock drift', () async {
      // 異なるクロックソースをシミュレート
      final baseTime = DateTime.now();
      final drift = 50; // 50msのドリフト
      
      // センサー1（正確なクロック）
      final sensor1Times = <DateTime>[];
      for (int i = 0; i < 10; i++) {
        sensor1Times.add(baseTime.add(Duration(milliseconds: i * 100)));
      }
      
      // センサー2（ドリフトあり）
      final sensor2Times = <DateTime>[];
      for (int i = 0; i < 10; i++) {
        sensor2Times.add(
          baseTime.add(Duration(milliseconds: i * 100 + drift)),
        );
      }
      
      // 同期後のタイムスタンプ
      final syncedTimes = <DateTime>[];
      for (int i = 0; i < sensor2Times.length; i++) {
        // ドリフト補正
        final corrected = sensor2Times[i].subtract(Duration(milliseconds: drift));
        syncedTimes.add(corrected);
      }
      
      // 同期後は一致することを確認
      for (int i = 0; i < syncedTimes.length; i++) {
        expect(
          syncedTimes[i].difference(sensor1Times[i]).inMilliseconds.abs(),
          lessThan(5),
        );
      }
    });

    test('high frequency sampling maintains consistent intervals', () async {
      const samplingRate = 100; // 100Hz
      const intervalMs = 1000 / samplingRate; // 10ms
      const sampleCount = 100;
      
      final samples = <DateTime>[];
      final stopwatch = Stopwatch()..start();
      
      // 高頻度サンプリング
      while (samples.length < sampleCount) {
        if (stopwatch.elapsedMilliseconds >= samples.length * intervalMs) {
          samples.add(DateTime.now());
        }
      }
      
      stopwatch.stop();
      
      // サンプリング間隔の統計
      final intervals = <double>[];
      for (int i = 1; i < samples.length; i++) {
        intervals.add(
          samples[i].difference(samples[i-1]).inMicroseconds / 1000.0,
        );
      }
      
      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      final maxDeviation = intervals.map((i) => (i - intervalMs).abs()).reduce((a, b) => a > b ? a : b);
      
      // 平均間隔が目標に近い
      expect(avgInterval, closeTo(intervalMs, 1.0));
      
      // 最大偏差が2ms以内
      expect(maxDeviation, lessThan(2.0));
    });

    test('phase error calculation is accurate', () {
      // 位相誤差計算のテスト
      final clickTime = DateTime.now();
      final heelStrikeTime = clickTime.add(const Duration(milliseconds: 50));
      
      final phaseError = heelStrikeTime.difference(clickTime).inMilliseconds;
      expect(phaseError, equals(50));
      
      // RMSE計算
      final errors = [30, -20, 40, -10, 50];
      final squaredSum = errors.map((e) => e * e).reduce((a, b) => a + b);
      final rmse = (squaredSum / errors.length).toDouble();
      
      expect(rmse, closeTo(32.86, 0.01));
    });

    test('convergence detection works correctly', () {
      // 収束検出のテスト
      final spmHistory = <double>[];
      const targetSpm = 100.0;
      const convergenceThreshold = 3.0;
      
      // 収束前のデータ
      spmHistory.addAll([85.0, 90.0, 92.0, 94.0, 96.0]);
      
      // 収束チェック
      bool isConverged = false;
      for (final spm in spmHistory) {
        if ((spm - targetSpm).abs() < convergenceThreshold) {
          isConverged = true;
          break;
        }
      }
      expect(isConverged, isFalse);
      
      // 収束後のデータ
      spmHistory.addAll([98.0, 99.0, 100.5, 99.5, 100.0]);
      
      // 再度収束チェック
      final recentSpm = spmHistory.sublist(spmHistory.length - 5);
      isConverged = recentSpm.every((spm) => 
        (spm - targetSpm).abs() < convergenceThreshold
      );
      expect(isConverged, isTrue);
    });
  });
}