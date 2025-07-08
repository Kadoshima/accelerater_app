import 'dart:async';
import 'dart:math' as math;

/// リアルタイムパフォーマンスモニター
/// 歩行速度とN-back課題の精度を監視
class PerformanceMonitor {
  // 歩行パフォーマンス
  final List<WalkingPerformance> _walkingHistory = [];
  final List<NBackPerformance> _nbackHistory = [];
  
  // ストリームコントローラー
  final _performanceStreamController = StreamController<PerformanceUpdate>.broadcast();
  final _alertStreamController = StreamController<PerformanceAlert>.broadcast();
  
  // 設定パラメータ
  final int historyWindowSeconds;
  final double walkingSpeedThreshold; // m/s
  final double accuracyThreshold; // 0-1
  
  // 現在の状態
  double _currentWalkingSpeed = 0.0;
  double _currentNBackAccuracy = 1.0;
  int _consecutiveLowPerformance = 0;
  
  PerformanceMonitor({
    this.historyWindowSeconds = 30,
    this.walkingSpeedThreshold = 0.8, // 0.8 m/s以下で警告
    this.accuracyThreshold = 0.6, // 60%以下で警告
  });
  
  /// パフォーマンス更新ストリーム
  Stream<PerformanceUpdate> get performanceStream => _performanceStreamController.stream;
  
  /// アラートストリーム
  Stream<PerformanceAlert> get alertStream => _alertStreamController.stream;
  
  /// 歩行データを更新
  void updateWalkingData({
    required double speed,
    required double spm,
    required double cv,
    required DateTime timestamp,
  }) {
    _currentWalkingSpeed = speed;
    
    final performance = WalkingPerformance(
      timestamp: timestamp,
      speed: speed,
      spm: spm,
      cv: cv,
    );
    
    _walkingHistory.add(performance);
    _cleanupOldData();
    
    _checkPerformance();
    _emitUpdate();
  }
  
  /// N-back課題のパフォーマンスを更新
  void updateNBackPerformance({
    required bool correct,
    required int responseTimeMs,
    required int nLevel,
    required DateTime timestamp,
  }) {
    final performance = NBackPerformance(
      timestamp: timestamp,
      correct: correct,
      responseTimeMs: responseTimeMs,
      nLevel: nLevel,
    );
    
    _nbackHistory.add(performance);
    _cleanupOldData();
    
    // 精度を再計算
    _currentNBackAccuracy = _calculateRecentAccuracy();
    
    _checkPerformance();
    _emitUpdate();
  }
  
  /// 最近の精度を計算
  double _calculateRecentAccuracy() {
    if (_nbackHistory.isEmpty) return 1.0;
    
    final recentCutoff = DateTime.now().subtract(Duration(seconds: historyWindowSeconds));
    final recentTrials = _nbackHistory.where((p) => p.timestamp.isAfter(recentCutoff)).toList();
    
    if (recentTrials.isEmpty) return 1.0;
    
    final correctCount = recentTrials.where((p) => p.correct).length;
    return correctCount / recentTrials.length;
  }
  
  /// パフォーマンスをチェックしてアラートを発行
  void _checkPerformance() {
    bool lowPerformance = false;
    final alerts = <String>[];
    
    // 歩行速度チェック
    if (_currentWalkingSpeed < walkingSpeedThreshold && _currentWalkingSpeed > 0) {
      lowPerformance = true;
      alerts.add('歩行速度が低下しています (${_currentWalkingSpeed.toStringAsFixed(2)} m/s)');
    }
    
    // N-back精度チェック
    if (_currentNBackAccuracy < accuracyThreshold && _nbackHistory.isNotEmpty) {
      lowPerformance = true;
      alerts.add('認知課題の精度が低下しています (${(_currentNBackAccuracy * 100).toStringAsFixed(0)}%)');
    }
    
    // 連続低パフォーマンスをトラック
    if (lowPerformance) {
      _consecutiveLowPerformance++;
      
      if (_consecutiveLowPerformance >= 3) {
        _alertStreamController.add(PerformanceAlert(
          timestamp: DateTime.now(),
          severity: AlertSeverity.high,
          messages: alerts,
          recommendation: '休憩を検討してください',
        ));
      } else {
        _alertStreamController.add(PerformanceAlert(
          timestamp: DateTime.now(),
          severity: AlertSeverity.medium,
          messages: alerts,
          recommendation: 'パフォーマンスに注意してください',
        ));
      }
    } else {
      _consecutiveLowPerformance = 0;
    }
  }
  
  /// 現在の状態を更新として発行
  void _emitUpdate() {
    final walkingMetrics = _calculateWalkingMetrics();
    final cognitiveMetrics = _calculateCognitiveMetrics();
    
    _performanceStreamController.add(PerformanceUpdate(
      timestamp: DateTime.now(),
      walkingSpeed: _currentWalkingSpeed,
      walkingSpm: walkingMetrics['spm'] ?? 0.0,
      walkingCv: walkingMetrics['cv'] ?? 0.0,
      nbackAccuracy: _currentNBackAccuracy,
      nbackResponseTime: cognitiveMetrics['avgResponseTime'] ?? 0,
      overallScore: _calculateOverallScore(),
    ));
  }
  
  /// 歩行メトリクスを計算
  Map<String, double> _calculateWalkingMetrics() {
    if (_walkingHistory.isEmpty) return {};
    
    final recentCutoff = DateTime.now().subtract(Duration(seconds: historyWindowSeconds));
    final recent = _walkingHistory.where((p) => p.timestamp.isAfter(recentCutoff)).toList();
    
    if (recent.isEmpty) return {};
    
    final avgSpm = recent.map((p) => p.spm).reduce((a, b) => a + b) / recent.length;
    final avgCv = recent.map((p) => p.cv).reduce((a, b) => a + b) / recent.length;
    
    return {
      'spm': avgSpm,
      'cv': avgCv,
    };
  }
  
  /// 認知メトリクスを計算
  Map<String, dynamic> _calculateCognitiveMetrics() {
    if (_nbackHistory.isEmpty) return {};
    
    final recentCutoff = DateTime.now().subtract(Duration(seconds: historyWindowSeconds));
    final recent = _nbackHistory.where((p) => p.timestamp.isAfter(recentCutoff)).toList();
    
    if (recent.isEmpty) return {};
    
    final avgResponseTime = recent
        .map((p) => p.responseTimeMs)
        .reduce((a, b) => a + b) / recent.length;
    
    return {
      'avgResponseTime': avgResponseTime.round(),
      'trialCount': recent.length,
    };
  }
  
  /// 総合スコアを計算（0-100）
  double _calculateOverallScore() {
    // 歩行スコア（速度基準）
    double walkingScore = 50.0;
    if (_currentWalkingSpeed > 0) {
      walkingScore = math.min(100, (_currentWalkingSpeed / 1.5) * 100);
    }
    
    // 認知スコア（精度基準）
    final cognitiveScore = _currentNBackAccuracy * 100;
    
    // 重み付け平均（歩行:認知 = 1:1）
    return (walkingScore + cognitiveScore) / 2;
  }
  
  /// 古いデータをクリーンアップ
  void _cleanupOldData() {
    final cutoff = DateTime.now().subtract(Duration(seconds: historyWindowSeconds * 2));
    
    _walkingHistory.removeWhere((p) => p.timestamp.isBefore(cutoff));
    _nbackHistory.removeWhere((p) => p.timestamp.isBefore(cutoff));
  }
  
  /// 現在のパフォーマンスサマリーを取得
  PerformanceSummary getCurrentSummary() {
    final walkingMetrics = _calculateWalkingMetrics();
    final cognitiveMetrics = _calculateCognitiveMetrics();
    
    return PerformanceSummary(
      timestamp: DateTime.now(),
      walkingSpeed: _currentWalkingSpeed,
      walkingSpm: walkingMetrics['spm'] ?? 0.0,
      walkingCv: walkingMetrics['cv'] ?? 0.0,
      nbackAccuracy: _currentNBackAccuracy,
      nbackResponseTime: cognitiveMetrics['avgResponseTime'] ?? 0,
      nbackTrialCount: cognitiveMetrics['trialCount'] ?? 0,
      overallScore: _calculateOverallScore(),
      consecutiveLowPerformance: _consecutiveLowPerformance,
    );
  }
  
  /// セッション統計を取得
  SessionStatistics getSessionStatistics() {
    if (_walkingHistory.isEmpty && _nbackHistory.isEmpty) {
      return SessionStatistics.empty();
    }
    
    // 歩行統計
    double avgSpeed = 0;
    double maxSpeed = 0;
    double minSpeed = double.infinity;
    
    if (_walkingHistory.isNotEmpty) {
      avgSpeed = _walkingHistory.map((p) => p.speed).reduce((a, b) => a + b) / _walkingHistory.length;
      maxSpeed = _walkingHistory.map((p) => p.speed).reduce(math.max);
      minSpeed = _walkingHistory.map((p) => p.speed).reduce(math.min);
    }
    
    // N-back統計
    int totalTrials = _nbackHistory.length;
    int correctTrials = _nbackHistory.where((p) => p.correct).length;
    double accuracy = totalTrials > 0 ? correctTrials / totalTrials : 0;
    
    double avgResponseTime = 0;
    if (_nbackHistory.isNotEmpty) {
      avgResponseTime = _nbackHistory
          .map((p) => p.responseTimeMs)
          .reduce((a, b) => a + b) / _nbackHistory.length;
    }
    
    return SessionStatistics(
      duration: _calculateSessionDuration(),
      avgWalkingSpeed: avgSpeed,
      maxWalkingSpeed: maxSpeed,
      minWalkingSpeed: minSpeed == double.infinity ? 0 : minSpeed,
      totalNBackTrials: totalTrials,
      nbackAccuracy: accuracy,
      avgResponseTime: avgResponseTime,
      performanceAlerts: _consecutiveLowPerformance,
    );
  }
  
  Duration _calculateSessionDuration() {
    DateTime? earliest;
    DateTime? latest;
    
    for (final p in _walkingHistory) {
      earliest = earliest == null || p.timestamp.isBefore(earliest) ? p.timestamp : earliest;
      latest = latest == null || p.timestamp.isAfter(latest) ? p.timestamp : latest;
    }
    
    for (final p in _nbackHistory) {
      earliest = earliest == null || p.timestamp.isBefore(earliest) ? p.timestamp : earliest;
      latest = latest == null || p.timestamp.isAfter(latest) ? p.timestamp : latest;
    }
    
    if (earliest != null && latest != null) {
      return latest.difference(earliest);
    }
    
    return Duration.zero;
  }
  
  void dispose() {
    _performanceStreamController.close();
    _alertStreamController.close();
  }
}

/// 歩行パフォーマンスデータ
class WalkingPerformance {
  final DateTime timestamp;
  final double speed; // m/s
  final double spm;
  final double cv;
  
  WalkingPerformance({
    required this.timestamp,
    required this.speed,
    required this.spm,
    required this.cv,
  });
}

/// N-backパフォーマンスデータ
class NBackPerformance {
  final DateTime timestamp;
  final bool correct;
  final int responseTimeMs;
  final int nLevel;
  
  NBackPerformance({
    required this.timestamp,
    required this.correct,
    required this.responseTimeMs,
    required this.nLevel,
  });
}

/// パフォーマンス更新
class PerformanceUpdate {
  final DateTime timestamp;
  final double walkingSpeed;
  final double walkingSpm;
  final double walkingCv;
  final double nbackAccuracy;
  final int nbackResponseTime;
  final double overallScore;
  
  PerformanceUpdate({
    required this.timestamp,
    required this.walkingSpeed,
    required this.walkingSpm,
    required this.walkingCv,
    required this.nbackAccuracy,
    required this.nbackResponseTime,
    required this.overallScore,
  });
}

/// パフォーマンスアラート
class PerformanceAlert {
  final DateTime timestamp;
  final AlertSeverity severity;
  final List<String> messages;
  final String recommendation;
  
  PerformanceAlert({
    required this.timestamp,
    required this.severity,
    required this.messages,
    required this.recommendation,
  });
}

enum AlertSeverity { low, medium, high }

/// パフォーマンスサマリー
class PerformanceSummary {
  final DateTime timestamp;
  final double walkingSpeed;
  final double walkingSpm;
  final double walkingCv;
  final double nbackAccuracy;
  final int nbackResponseTime;
  final int nbackTrialCount;
  final double overallScore;
  final int consecutiveLowPerformance;
  
  PerformanceSummary({
    required this.timestamp,
    required this.walkingSpeed,
    required this.walkingSpm,
    required this.walkingCv,
    required this.nbackAccuracy,
    required this.nbackResponseTime,
    required this.nbackTrialCount,
    required this.overallScore,
    required this.consecutiveLowPerformance,
  });
}

/// セッション統計
class SessionStatistics {
  final Duration duration;
  final double avgWalkingSpeed;
  final double maxWalkingSpeed;
  final double minWalkingSpeed;
  final int totalNBackTrials;
  final double nbackAccuracy;
  final double avgResponseTime;
  final int performanceAlerts;
  
  SessionStatistics({
    required this.duration,
    required this.avgWalkingSpeed,
    required this.maxWalkingSpeed,
    required this.minWalkingSpeed,
    required this.totalNBackTrials,
    required this.nbackAccuracy,
    required this.avgResponseTime,
    required this.performanceAlerts,
  });
  
  factory SessionStatistics.empty() {
    return SessionStatistics(
      duration: Duration.zero,
      avgWalkingSpeed: 0,
      maxWalkingSpeed: 0,
      minWalkingSpeed: 0,
      totalNBackTrials: 0,
      nbackAccuracy: 0,
      avgResponseTime: 0,
      performanceAlerts: 0,
    );
  }
}