import 'dart:math' as math;

/// 心拍変動（HRV）計算サービス
/// SDNN（Standard Deviation of NN intervals）を計算
class HRVCalculator {
  final List<RRInterval> _rrIntervals = [];
  final int windowSizeSeconds;
  
  HRVCalculator({
    this.windowSizeSeconds = 300, // デフォルト5分
  });
  
  /// R-R間隔を追加
  void addRRInterval({
    required int intervalMs,
    required DateTime timestamp,
  }) {
    _rrIntervals.add(RRInterval(
      intervalMs: intervalMs,
      timestamp: timestamp,
    ));
    
    // 古いデータをクリーンアップ
    _cleanupOldData();
  }
  
  /// 複数のR-R間隔を一度に追加
  void addRRIntervals(List<int> intervals, DateTime startTime) {
    DateTime currentTime = startTime;
    
    for (final interval in intervals) {
      _rrIntervals.add(RRInterval(
        intervalMs: interval,
        timestamp: currentTime,
      ));
      currentTime = currentTime.add(Duration(milliseconds: interval));
    }
    
    _cleanupOldData();
  }
  
  /// SDNN（NN間隔の標準偏差）を計算
  double calculateSDNN() {
    if (_rrIntervals.length < 2) return 0.0;
    
    final intervals = _rrIntervals.map((rr) => rr.intervalMs.toDouble()).toList();
    return _calculateStandardDeviation(intervals);
  }
  
  /// 時間枠指定でSDNNを計算
  double calculateSDNNForTimeWindow({
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final windowIntervals = _rrIntervals
        .where((rr) => 
            rr.timestamp.isAfter(startTime) && 
            rr.timestamp.isBefore(endTime))
        .map((rr) => rr.intervalMs.toDouble())
        .toList();
    
    if (windowIntervals.length < 2) return 0.0;
    
    return _calculateStandardDeviation(windowIntervals);
  }
  
  /// RMSSD（Root Mean Square of Successive Differences）を計算
  double calculateRMSSD() {
    if (_rrIntervals.length < 2) return 0.0;
    
    double sumSquaredDiff = 0.0;
    int count = 0;
    
    for (int i = 1; i < _rrIntervals.length; i++) {
      final diff = (_rrIntervals[i].intervalMs - _rrIntervals[i-1].intervalMs).toDouble();
      sumSquaredDiff += diff * diff;
      count++;
    }
    
    if (count == 0) return 0.0;
    
    return math.sqrt(sumSquaredDiff / count);
  }
  
  /// pNN50（連続するRR間隔の差が50ms以上の割合）を計算
  double calculatePNN50() {
    if (_rrIntervals.length < 2) return 0.0;
    
    int count50ms = 0;
    int totalPairs = 0;
    
    for (int i = 1; i < _rrIntervals.length; i++) {
      final diff = (_rrIntervals[i].intervalMs - _rrIntervals[i-1].intervalMs).abs();
      if (diff > 50) {
        count50ms++;
      }
      totalPairs++;
    }
    
    if (totalPairs == 0) return 0.0;
    
    return (count50ms / totalPairs) * 100; // パーセンテージで返す
  }
  
  /// 心拍数（BPM）を計算
  double calculateHeartRate() {
    if (_rrIntervals.isEmpty) return 0.0;
    
    final avgInterval = _rrIntervals
        .map((rr) => rr.intervalMs)
        .reduce((a, b) => a + b) / _rrIntervals.length;
    
    return 60000 / avgInterval; // 60秒 / 平均RR間隔
  }
  
  /// HRVメトリクスの包括的な計算
  HRVMetrics calculateAllMetrics() {
    return HRVMetrics(
      timestamp: DateTime.now(),
      sdnn: calculateSDNN(),
      rmssd: calculateRMSSD(),
      pnn50: calculatePNN50(),
      heartRate: calculateHeartRate(),
      sampleCount: _rrIntervals.length,
    );
  }
  
  /// ストレスレベルの推定（0-100）
  /// SDNNとRMSSDを基に簡易的に推定
  double estimateStressLevel() {
    final sdnn = calculateSDNN();
    final rmssd = calculateRMSSD();
    
    // SDNNが低いほどストレスが高い
    // 正常範囲: 50-100ms
    double sdnnScore = 0.0;
    if (sdnn > 100) {
      sdnnScore = 0.0; // 非常に低ストレス
    } else if (sdnn > 50) {
      sdnnScore = (100 - sdnn) / 50 * 50; // 0-50
    } else {
      sdnnScore = 50 + (50 - sdnn); // 50-100
    }
    
    // RMSSDが低いほどストレスが高い
    // 正常範囲: 20-50ms
    double rmssdScore = 0.0;
    if (rmssd > 50) {
      rmssdScore = 0.0; // 非常に低ストレス
    } else if (rmssd > 20) {
      rmssdScore = (50 - rmssd) / 30 * 50; // 0-50
    } else {
      rmssdScore = 50 + (20 - rmssd) * 2.5; // 50-100
    }
    
    // 平均を取る
    return (sdnnScore + rmssdScore) / 2;
  }
  
  /// 自律神経バランスの評価
  AutonomicBalance evaluateAutonomicBalance() {
    final rmssd = calculateRMSSD();
    final sdnn = calculateSDNN();
    final pnn50 = calculatePNN50();
    
    // RMSSDとpNN50は副交感神経活動の指標
    // SDNNは全体的な自律神経活動の指標
    
    double parasympatheticScore = 0.0;
    double sympatheticScore = 0.0;
    
    // 副交感神経スコア（RMSSD基準）
    if (rmssd > 50) {
      parasympatheticScore = 1.0;
    } else if (rmssd > 30) {
      parasympatheticScore = 0.7;
    } else if (rmssd > 20) {
      parasympatheticScore = 0.5;
    } else {
      parasympatheticScore = 0.3;
    }
    
    // pNN50も考慮
    if (pnn50 > 20) {
      parasympatheticScore = math.min(1.0, parasympatheticScore + 0.2);
    }
    
    // 交感神経スコア（SDNNとRMSSDの比率から推定）
    if (sdnn > 0 && rmssd > 0) {
      final ratio = sdnn / rmssd;
      if (ratio > 3) {
        sympatheticScore = 0.8;
      } else if (ratio > 2) {
        sympatheticScore = 0.6;
      } else {
        sympatheticScore = 0.4;
      }
    }
    
    return AutonomicBalance(
      parasympatheticScore: parasympatheticScore,
      sympatheticScore: sympatheticScore,
      balance: parasympatheticScore - sympatheticScore,
    );
  }
  
  /// 標準偏差を計算
  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDifferences = values.map((v) => math.pow(v - mean, 2)).toList();
    final variance = squaredDifferences.reduce((a, b) => a + b) / values.length;
    
    return math.sqrt(variance);
  }
  
  /// 古いデータをクリーンアップ
  void _cleanupOldData() {
    final cutoff = DateTime.now().subtract(Duration(seconds: windowSizeSeconds * 2));
    _rrIntervals.removeWhere((rr) => rr.timestamp.isBefore(cutoff));
  }
  
  /// データをクリア
  void clear() {
    _rrIntervals.clear();
  }
  
  /// 現在のデータ数を取得
  int get dataCount => _rrIntervals.length;
}

/// R-R間隔データ
class RRInterval {
  final int intervalMs;
  final DateTime timestamp;
  
  RRInterval({
    required this.intervalMs,
    required this.timestamp,
  });
}

/// HRVメトリクス
class HRVMetrics {
  final DateTime timestamp;
  final double sdnn; // NN間隔の標準偏差
  final double rmssd; // 連続する差の二乗平均平方根
  final double pnn50; // 50ms以上の差の割合
  final double heartRate; // 心拍数（BPM）
  final int sampleCount; // サンプル数
  
  HRVMetrics({
    required this.timestamp,
    required this.sdnn,
    required this.rmssd,
    required this.pnn50,
    required this.heartRate,
    required this.sampleCount,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'sdnn': sdnn,
      'rmssd': rmssd,
      'pnn50': pnn50,
      'heartRate': heartRate,
      'sampleCount': sampleCount,
    };
  }
}

/// 自律神経バランス
class AutonomicBalance {
  final double parasympatheticScore; // 副交感神経スコア（0-1）
  final double sympatheticScore; // 交感神経スコア（0-1）
  final double balance; // バランス（-1から1、正が副交感神経優位）
  
  AutonomicBalance({
    required this.parasympatheticScore,
    required this.sympatheticScore,
    required this.balance,
  });
  
  String get description {
    if (balance > 0.3) {
      return 'リラックス状態（副交感神経優位）';
    } else if (balance < -0.3) {
      return '緊張・ストレス状態（交感神経優位）';
    } else {
      return 'バランス状態';
    }
  }
}