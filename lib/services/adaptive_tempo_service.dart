import 'dart:collection';

/// 可変難度・二重課題プロトコル用の適応的テンポサービス
/// 最小二乗線形予測アルゴリズムを用いた位相誤差補正
class AdaptiveTempoService {
  // ゲインパラメータ（実装TODO.mdより）
  static const double kPhi = 0.35; // 位相ゲイン
  static const double kT = 0.10;   // 周期ゲイン
  
  // 内部状態
  double _currentBpm = 100.0;
  double _previousError = 0.0;
  
  // 位相予測用のデータバッファ
  final Queue<PhaseData> _phaseHistory = Queue<PhaseData>();
  static const int _historySize = 10; // 過去10歩分のデータを保持
  
  // 線形予測モデルのパラメータ
  double _phaseSlope = 0.0;     // 位相の傾き
  double _phaseIntercept = 0.0; // 位相の切片
  bool _isModelValid = false;
  
  /// サービスの初期化
  void initialize(double initialBpm) {
    _currentBpm = initialBpm;
    _phaseHistory.clear();
    _isModelValid = false;
    _previousError = 0.0;
  }
  
  /// リアルタイムBPM更新
  /// clickTime: メトロノームクリック時刻
  /// heelStrikeTime: かかと接地時刻
  /// returns: 更新後のBPM
  double updateBpm({
    required DateTime clickTime,
    required DateTime heelStrikeTime,
  }) {
    // 位相誤差の計算 (ミリ秒単位)
    final error = clickTime.difference(heelStrikeTime).inMilliseconds / 1000.0;
    
    // 位相データを履歴に追加
    _addPhaseData(heelStrikeTime, error);
    
    // 最小二乗法で将来位相を予測
    if (_phaseHistory.length >= 3) {
      _updateLinearModel();
    }
    
    // 予測を使用した誤差補正
    double correctedError = error;
    if (_isModelValid) {
      // 次の歩行周期での予測位相誤差
      final predictedError = _predictNextPhaseError();
      // 予測を考慮した補正
      correctedError = error * 0.7 + predictedError * 0.3;
    }
    
    // BPM更新式: BPM_t+1 = BPM_t + kϕ·e_t + kT·(e_t - e_t-1)
    final deltaBpm = kPhi * correctedError + kT * (correctedError - _previousError);
    _currentBpm += deltaBpm;
    
    // BPMを妥当な範囲に制限
    _currentBpm = _currentBpm.clamp(60.0, 200.0);
    
    // 状態更新
    _previousError = correctedError;
    
    return _currentBpm;
  }
  
  /// 位相データを履歴に追加
  void _addPhaseData(DateTime timestamp, double phaseError) {
    _phaseHistory.add(PhaseData(timestamp: timestamp, phaseError: phaseError));
    
    // 履歴サイズを制限
    while (_phaseHistory.length > _historySize) {
      _phaseHistory.removeFirst();
    }
  }
  
  /// 最小二乗法による線形モデルの更新
  void _updateLinearModel() {
    if (_phaseHistory.length < 3) {
      _isModelValid = false;
      return;
    }
    
    // タイムスタンプを相対時間（秒）に変換
    final firstTime = _phaseHistory.first.timestamp;
    final List<double> times = [];
    final List<double> phases = [];
    
    for (final data in _phaseHistory) {
      final relativeTime = data.timestamp.difference(firstTime).inMilliseconds / 1000.0;
      times.add(relativeTime);
      phases.add(data.phaseError);
    }
    
    // 最小二乗法の計算
    final n = times.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    
    for (int i = 0; i < n; i++) {
      sumX += times[i];
      sumY += phases[i];
      sumXY += times[i] * phases[i];
      sumX2 += times[i] * times[i];
    }
    
    // 線形回帰の係数計算
    final denominator = n * sumX2 - sumX * sumX;
    if (denominator.abs() < 0.0001) {
      _isModelValid = false;
      return;
    }
    
    _phaseSlope = (n * sumXY - sumX * sumY) / denominator;
    _phaseIntercept = (sumY - _phaseSlope * sumX) / n;
    _isModelValid = true;
  }
  
  /// 次の位相誤差を予測
  double _predictNextPhaseError() {
    if (!_isModelValid || _phaseHistory.isEmpty) {
      return _previousError;
    }
    
    // 現在から次の歩行周期（約1秒後）の予測
    final lastTime = _phaseHistory.last.timestamp;
    final firstTime = _phaseHistory.first.timestamp;
    final currentRelativeTime = lastTime.difference(firstTime).inMilliseconds / 1000.0;
    
    // 1秒後の予測値
    final predictedTime = currentRelativeTime + 1.0;
    final predictedError = _phaseSlope * predictedTime + _phaseIntercept;
    
    // 予測値を妥当な範囲に制限
    return predictedError.clamp(-0.5, 0.5);
  }
  
  /// 現在のBPMを取得
  double get currentBpm => _currentBpm;
  
  /// 予測モデルの有効性を取得
  bool get isModelValid => _isModelValid;
  
  /// デバッグ情報を取得
  Map<String, dynamic> getDebugInfo() {
    return {
      'currentBpm': _currentBpm,
      'previousError': _previousError,
      'phaseSlope': _phaseSlope,
      'phaseIntercept': _phaseIntercept,
      'isModelValid': _isModelValid,
      'historySize': _phaseHistory.length,
      'kPhi': kPhi,
      'kT': kT,
    };
  }
  
  /// 位相履歴をクリア
  void clearHistory() {
    _phaseHistory.clear();
    _isModelValid = false;
  }
}

/// 位相データのモデル
class PhaseData {
  final DateTime timestamp;
  final double phaseError;
  
  PhaseData({
    required this.timestamp,
    required this.phaseError,
  });
}