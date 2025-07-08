import 'dart:math' as math;
import 'dart:collection';

/// 位相誤差の計算とRMSE評価を行うエンジン
class PhaseErrorEngine {
  // 位相誤差の履歴
  final Queue<PhaseErrorData> _errorHistory = Queue<PhaseErrorData>();
  final int _maxHistorySize = 300; // 5分間のデータ（1秒1データとして）
  
  // 収束判定パラメータ
  static const double _convergenceThreshold = 3.0; // SPM差の閾値
  static const int _convergenceWindow = 10; // 収束判定ウィンドウ（秒）
  
  // 統計情報
  double _rmsePhi = 0.0;
  double? _convergenceTime;
  DateTime? _convergenceTimestamp;
  DateTime _startTime = DateTime.now();
  
  // ターゲットSPM
  double _targetSpm = 100.0;
  
  /// エンジンの初期化
  void initialize(double targetSpm) {
    _targetSpm = targetSpm;
    _errorHistory.clear();
    _rmsePhi = 0.0;
    _convergenceTime = null;
    _convergenceTimestamp = null;
    _startTime = DateTime.now();
  }
  
  /// リアルタイム位相誤差の記録
  /// clickTime: メトロノームクリック時刻
  /// heelStrikeTime: かかと接地時刻
  /// currentSpm: 現在のSPM
  void recordPhaseError({
    required DateTime clickTime,
    required DateTime heelStrikeTime,
    required double currentSpm,
  }) {
    // e_t = click_t - heelstrike_t (秒単位)
    final error = clickTime.difference(heelStrikeTime).inMilliseconds / 1000.0;
    
    final errorData = PhaseErrorData(
      timestamp: heelStrikeTime,
      phaseError: error,
      currentSpm: currentSpm,
    );
    
    _errorHistory.add(errorData);
    
    // 履歴サイズ制限
    while (_errorHistory.length > _maxHistorySize) {
      _errorHistory.removeFirst();
    }
    
    // RMSE更新
    _updateRmse();
    
    // 収束時間の自動検出
    if (_convergenceTime == null) {
      _checkConvergence();
    }
  }
  
  /// RMSEの更新計算
  void _updateRmse() {
    if (_errorHistory.isEmpty) {
      _rmsePhi = 0.0;
      return;
    }
    
    // RMSE_φ = √(Σ(e_t)²/n)
    double sumSquaredErrors = 0.0;
    for (final data in _errorHistory) {
      sumSquaredErrors += data.phaseError * data.phaseError;
    }
    
    _rmsePhi = math.sqrt(sumSquaredErrors / _errorHistory.length);
  }
  
  /// 収束時間の自動検出
  void _checkConvergence() {
    if (_errorHistory.length < _convergenceWindow) {
      return;
    }
    
    // 最新のデータを確認
    final recentData = _errorHistory.toList()
        .sublist(_errorHistory.length - _convergenceWindow);
    
    // SPM差が閾値内に収まっているか確認
    bool isConverged = true;
    for (final data in recentData) {
      final spmDiff = (data.currentSpm - _targetSpm).abs();
      if (spmDiff >= _convergenceThreshold) {
        isConverged = false;
        break;
      }
    }
    
    if (isConverged) {
      // 収束時刻を記録
      _convergenceTimestamp = recentData.first.timestamp;
      _convergenceTime = _convergenceTimestamp!.difference(_startTime).inSeconds.toDouble();
    }
  }
  
  /// 現在のRMSE値を取得
  double get rmsePhi => _rmsePhi;
  
  /// 収束時間を取得（秒単位、未収束の場合null）
  double? get convergenceTime => _convergenceTime;
  
  /// 最近の位相誤差を取得（デバッグ用）
  List<double> getRecentErrors({int count = 10}) {
    final errors = <double>[];
    final startIndex = math.max(0, _errorHistory.length - count);
    
    _errorHistory.toList().sublist(startIndex).forEach((data) {
      errors.add(data.phaseError);
    });
    
    return errors;
  }
  
  /// 統計情報を取得
  Map<String, dynamic> getStatistics() {
    if (_errorHistory.isEmpty) {
      return {
        'rmsePhi': 0.0,
        'convergenceTime': null,
        'meanError': 0.0,
        'stdError': 0.0,
        'dataPoints': 0,
      };
    }
    
    // 平均誤差
    double sumErrors = 0.0;
    for (final data in _errorHistory) {
      sumErrors += data.phaseError;
    }
    final meanError = sumErrors / _errorHistory.length;
    
    // 標準偏差
    double sumSquaredDiff = 0.0;
    for (final data in _errorHistory) {
      final diff = data.phaseError - meanError;
      sumSquaredDiff += diff * diff;
    }
    final stdError = math.sqrt(sumSquaredDiff / _errorHistory.length);
    
    return {
      'rmsePhi': _rmsePhi,
      'convergenceTime': _convergenceTime,
      'meanError': meanError,
      'stdError': stdError,
      'dataPoints': _errorHistory.length,
      'targetSpm': _targetSpm,
      'isConverged': _convergenceTime != null,
    };
  }
  
  /// CSV出力用のデータを生成
  Map<String, dynamic> getExportData() {
    final stats = getStatistics();
    return {
      'rmse_phi': _rmsePhi,
      'convergence_time_tc': _convergenceTime ?? -1, // 未収束の場合-1
      'mean_phase_error': stats['meanError'],
      'std_phase_error': stats['stdError'],
      'is_converged': _convergenceTime != null,
    };
  }
  
  /// データバッファリング用：最新のエラーデータを取得
  PhaseErrorData? getLatestError() {
    return _errorHistory.isEmpty ? null : _errorHistory.last;
  }
  
  /// ストリーミング用：指定時刻以降のデータを取得
  List<PhaseErrorData> getErrorsSince(DateTime since) {
    return _errorHistory
        .where((data) => data.timestamp.isAfter(since))
        .toList();
  }
}

/// 位相誤差データのモデル
class PhaseErrorData {
  final DateTime timestamp;
  final double phaseError;
  final double currentSpm;
  
  PhaseErrorData({
    required this.timestamp,
    required this.phaseError,
    required this.currentSpm,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'phaseError': phaseError,
      'currentSpm': currentSpm,
    };
  }
}