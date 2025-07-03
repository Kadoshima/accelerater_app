import 'dart:math' as math;

/// 歩行メトリクス計算エンジン
class GaitMetricsEngine {
  final int windowSizeSeconds;
  final double overlapRatio;
  
  GaitMetricsEngine({
    this.windowSizeSeconds = 10,
    this.overlapRatio = 0.5,
  });
  
  /// 歩行周期変動係数（CV）を計算
  /// [stepIntervals] - ステップ間隔のリスト（ミリ秒）
  double calculateCV(List<double> stepIntervals) {
    if (stepIntervals.isEmpty || stepIntervals.length < 3) {
      return 0.0;
    }
    
    final mean = _calculateMean(stepIntervals);
    if (mean == 0) return 0.0;
    
    final variance = stepIntervals
        .map((x) => math.pow(x - mean, 2))
        .reduce((a, b) => a + b) / stepIntervals.length;
    
    final stdDev = math.sqrt(variance);
    return (stdDev / mean) * 100; // パーセンテージで返す
  }
  
  /// Sample Entropyを計算
  /// [data] - 時系列データ
  /// [m] - パターン長（デフォルト: 2）
  /// [r] - 許容誤差（デフォルト: 0.2 * SD）
  double calculateSampleEntropy(List<double> data, {int m = 2, double? r}) {
    if (data.length < m + 1) {
      return 0.0;
    }
    
    // rが指定されていない場合は標準偏差の0.2倍を使用
    if (r == null) {
      final stdDev = _calculateStdDev(data);
      r = 0.2 * stdDev;
    }
    
    // m長のパターンマッチング
    int phiM = _countPatterns(data, m, r);
    int phiM1 = _countPatterns(data, m + 1, r);
    
    if (phiM1 == 0) {
      return double.infinity;
    }
    
    return -math.log(phiM1 / phiM);
  }
  
  /// 位相誤差RMSE（Root Mean Square Error）を計算
  /// [phaseErrors] - 位相誤差のリスト（ミリ秒）
  double calculatePhaseRMSE(List<double> phaseErrors) {
    if (phaseErrors.isEmpty) return 0.0;
    
    final squaredSum = phaseErrors
        .map((e) => e * e)
        .reduce((a, b) => a + b);
    
    return math.sqrt(squaredSum / phaseErrors.length);
  }
  
  /// 収束時間を計算
  /// [spmValues] - SPM値の時系列
  /// [targetSpm] - 目標SPM
  /// [threshold] - 収束判定閾値（デフォルト: 3 SPM）
  /// [timestamps] - タイムスタンプのリスト
  /// 戻り値: 収束までの時間（秒）、収束しない場合はnull
  double? calculateConvergenceTime({
    required List<double> spmValues,
    required double targetSpm,
    required List<DateTime> timestamps,
    double threshold = 3.0,
  }) {
    if (spmValues.length != timestamps.length || spmValues.isEmpty) {
      return null;
    }
    
    final startTime = timestamps.first;
    
    // 連続して閾値内に入っている必要がある期間（秒）
    const samplesRequired = 5; // 5サンプル連続
    
    int consecutiveCount = 0;
    
    for (int i = 0; i < spmValues.length; i++) {
      if ((spmValues[i] - targetSpm).abs() < threshold) {
        consecutiveCount++;
        
        if (consecutiveCount >= samplesRequired) {
          // 収束開始時点を計算
          final convergenceIndex = i - samplesRequired + 1;
          final convergenceTime = timestamps[convergenceIndex];
          return convergenceTime.difference(startTime).inMilliseconds / 1000.0;
        }
      } else {
        consecutiveCount = 0;
      }
    }
    
    return null; // 収束しなかった
  }
  
  /// 天井効果（ΔC）を計算
  /// ΔC = CV_fixed - CV_baseline
  double calculateCeilingEffect({
    required double cvFixed,
    required double cvBaseline,
  }) {
    return cvFixed - cvBaseline;
  }
  
  /// 回復効果（ΔR）を計算
  /// ΔR = CV_fixed - CV_adaptive
  double calculateRecoveryEffect({
    required double cvFixed,
    required double cvAdaptive,
  }) {
    return cvFixed - cvAdaptive;
  }
  
  /// ウィンドウごとのメトリクスを計算
  Map<String, dynamic> calculateWindowedMetrics({
    required List<double> stepIntervals,
    required List<DateTime> timestamps,
    required int windowIndex,
  }) {
    final cv = calculateCV(stepIntervals);
    final entropy = calculateSampleEntropy(stepIntervals);
    
    return {
      'window_index': windowIndex,
      'timestamp': timestamps.isNotEmpty ? timestamps.first : DateTime.now(),
      'cv': cv,
      'sample_entropy': entropy,
      'step_count': stepIntervals.length,
      'mean_interval': _calculateMean(stepIntervals),
      'std_interval': _calculateStdDev(stepIntervals),
    };
  }
  
  // ヘルパーメソッド
  
  double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }
  
  double _calculateStdDev(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = _calculateMean(values);
    final variance = values
        .map((x) => math.pow(x - mean, 2))
        .reduce((a, b) => a + b) / values.length;
    return math.sqrt(variance);
  }
  
  int _countPatterns(List<double> data, int m, double r) {
    int count = 0;
    final N = data.length - m;
    
    for (int i = 0; i < N; i++) {
      for (int j = i + 1; j < N; j++) {
        bool match = true;
        
        // m長のパターンを比較
        for (int k = 0; k < m; k++) {
          if ((data[i + k] - data[j + k]).abs() > r) {
            match = false;
            break;
          }
        }
        
        if (match) count++;
      }
    }
    
    return count;
  }
}