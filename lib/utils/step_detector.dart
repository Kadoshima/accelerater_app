import 'dart:collection';
import 'dart:math';

/// 歩行検出アルゴリズム用クラス
class StepDetector {
  // 加速度データのキュー
  final Queue<double> accelerationWindow = Queue<double>();
  final Queue<int> timestampWindow = Queue<int>();

  // ステップ検出のパラメータ
  final int _windowSize = 10; // 小さくして処理遅延を減らす
  final double _baseThreshold = 0.01; // 0.05 -> 0.01 (prominence 相当)
  double _adaptiveThreshold = 0.01; // 適応閾値も初期値を合わせる

  // ピーク検出用の変数
  bool _isPotentialPeak = false;
  double _lastPeakValue = 0;
  int _lastPeakTimestamp = 0;
  final List<int> stepTimestamps = [];
  final List<double> stepConfidences = []; // 各ステップの信頼度
  final int _minTimeBetweenSteps = 400; // 300ms -> 400ms (distance 0.4s相当)

  // BPM計算結果
  double? _lastCalculatedBpm;
  double _currentReliabilityScore = 0.0;

  // 信頼性スコアのゲッター
  double get reliabilityScore => _currentReliabilityScore;

  // 最後に計算されたBPM
  double? get lastCalculatedBpm => _lastCalculatedBpm;

  // データ追加メソッド
  void addAccelerationData(double value, int timestamp) {
    accelerationWindow.add(value);
    timestampWindow.add(timestamp);
    if (accelerationWindow.length > _windowSize) {
      accelerationWindow.removeFirst();
      timestampWindow.removeFirst();
    }
  }

  // ステップ検出メソッド
  bool detectStep(double value, int timestamp) {
    if (accelerationWindow.length < _windowSize) {
      return false;
    }

    final avg =
        accelerationWindow.reduce((a, b) => a + b) / accelerationWindow.length;
    final variance = accelerationWindow.fold<double>(
            0.0, (sum, val) => sum + (val - avg) * (val - avg)) /
        accelerationWindow.length;
    final std = sqrt(variance);

    _adaptiveThreshold = max(_baseThreshold, std * 0.5);

    if (!_isPotentialPeak && value > avg + _adaptiveThreshold) {
      _isPotentialPeak = true;
      return false;
    } else if (_isPotentialPeak && value < avg - _adaptiveThreshold) {
      _isPotentialPeak = false;

      if (_lastPeakTimestamp > 0 &&
          timestamp - _lastPeakTimestamp < _minTimeBetweenSteps) {
        return false;
      }

      _lastPeakValue = value;
      _lastPeakTimestamp = timestamp;
      stepTimestamps.add(timestamp);

      double confidence = min(1.0, value / (avg + _adaptiveThreshold * 2));
      stepConfidences.add(confidence);

      if (stepTimestamps.length > 20) {
        stepTimestamps.removeAt(0);
        stepConfidences.removeAt(0);
      }

      return true;
    }

    return false;
  }

  // BPM計算メソッド
  double? calculateBpm() {
    if (stepTimestamps.length < 2) {
      return null;
    }

    final intervals = <int>[];
    for (int i = 1; i < stepTimestamps.length; i++) {
      final interval = stepTimestamps[i] - stepTimestamps[i - 1];
      if (interval >= 400 && interval <= 2000) {
        intervals.add(interval);
      }
    }

    if (intervals.isEmpty) {
      return null;
    }

    final averageInterval =
        intervals.reduce((a, b) => a + b) / intervals.length;

    if (averageInterval <= 0) {
      return null;
    }

    final bpm = 60000 / averageInterval;
    _lastCalculatedBpm = bpm;
    return _lastCalculatedBpm;
  }

  // 信頼性スコアの更新
  void _updateReliabilityScore() {
    if (stepConfidences.isEmpty) {
      _currentReliabilityScore = 0.0;
      return;
    }

    int count = min(5, stepConfidences.length);
    double sum = 0.0;
    for (int i = stepConfidences.length - 1;
        i >= stepConfidences.length - count;
        i--) {
      sum += stepConfidences[i];
    }
    _currentReliabilityScore = sum / count;
  }

  // 最後に検出されたステップの間隔（ミリ秒）
  int? getLastStepInterval() {
    if (stepTimestamps.length >= 2) {
      return stepTimestamps.last - stepTimestamps[stepTimestamps.length - 2];
    }
    return null;
  }

  // リセットメソッド
  void reset() {
    accelerationWindow.clear();
    timestampWindow.clear();
    stepTimestamps.clear();
    stepConfidences.clear();
    _isPotentialPeak = false;
    _lastPeakValue = 0;
    _lastPeakTimestamp = 0;
    _lastCalculatedBpm = null;
    _currentReliabilityScore = 0.0;
    print("StepDetector reset.");
  }

  // 非同期で歩行検出を行うメソッド
  Future<void> processData(double accelerationValue, int timestamp) async {
    addAccelerationData(accelerationValue, timestamp);
    detectStep(accelerationValue, timestamp);
    calculateBpm();
    _updateReliabilityScore();
  }
}
