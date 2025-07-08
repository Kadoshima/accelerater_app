import 'dart:math' as math;
import '../../../core/plugins/research_plugin.dart';

/// 無意識的な歩行誘導のための適応的テンポ制御コントローラー
class AdaptiveTempoController {
  // 個人パラメータ
  double _baselineSpm = 0.0;
  double _currentTargetSpm = 0.0;
  double _maxComfortableSpm = 0.0;
  
  // 適応制御パラメータ
  final double _adaptationRate = 0.02; // 1秒あたりの最大変化率（2%）
  final double _comfortZoneRatio = 0.05; // 快適ゾーン（±5%）
  final double _microAdjustmentRange = 0.01; // 微調整範囲（±1%）
  
  // 個人差パラメータ
  double _responsivenessScore = 1.0; // 音刺激への反応性（0.5-2.0）
  double _stabilityPreference = 1.0; // 安定性重視度（0.5-2.0）
  
  // 履歴データ
  final List<double> _spmHistory = [];
  final List<double> _cvHistory = [];
  final int _historyWindowSize = 30; // 30秒分のデータ
  
  // 状態管理
  bool _isInitialized = false;
  DateTime _lastUpdateTime = DateTime.now();
  int _stableWalkingDuration = 0;
  
  /// 初期化とベースライン設定
  void initialize(double baselineSpm) {
    _baselineSpm = baselineSpm;
    _currentTargetSpm = baselineSpm;
    _maxComfortableSpm = baselineSpm * 1.15; // 初期値は15%増
    _isInitialized = true;
    _spmHistory.clear();
    _cvHistory.clear();
  }
  
  /// リアルタイムの歩行データを基に目標SPMを更新
  double updateTargetSpm({
    required double currentSpm,
    required double currentCv,
    required DateTime timestamp,
  }) {
    if (!_isInitialized) return _currentTargetSpm;
    
    // 履歴に追加
    _addToHistory(currentSpm, currentCv);
    
    // 時間差分を計算
    final timeDelta = timestamp.difference(_lastUpdateTime).inMilliseconds / 1000.0;
    _lastUpdateTime = timestamp;
    
    // 安定性を評価
    final stabilityScore = _evaluateStability();
    
    // 反応性を評価
    final responsivenessScore = _evaluateResponsiveness();
    
    // 目標SPMの微調整を計算
    double adjustment = _calculateAdjustment(
      currentSpm: currentSpm,
      stabilityScore: stabilityScore,
      responsivenessScore: responsivenessScore,
      timeDelta: timeDelta,
    );
    
    // 段階的に適用（無意識的な変化のため）
    _currentTargetSpm += adjustment;
    
    // 安全範囲内に制限
    _currentTargetSpm = _currentTargetSpm.clamp(
      _baselineSpm * 0.9,
      _maxComfortableSpm,
    );
    
    return _currentTargetSpm;
  }
  
  /// 歩行の安定性を評価
  double _evaluateStability() {
    if (_cvHistory.length < 5) return 0.5;
    
    // 最近のCV値の平均
    final recentCv = _cvHistory.skip(math.max(0, _cvHistory.length - 10))
        .reduce((a, b) => a + b) / math.min(10, _cvHistory.length);
    
    // CV値が低いほど安定（0.05以下が理想的）
    if (recentCv < 0.03) return 1.0;
    if (recentCv < 0.05) return 0.8;
    if (recentCv < 0.08) return 0.6;
    if (recentCv < 0.10) return 0.4;
    return 0.2;
  }
  
  /// 音刺激への反応性を評価
  double _evaluateResponsiveness() {
    if (_spmHistory.length < 10) return 0.5;
    
    // 目標SPMと実際のSPMの追従性を評価
    double totalDeviation = 0;
    int count = 0;
    
    for (int i = math.max(0, _spmHistory.length - 20); i < _spmHistory.length; i++) {
      final deviation = (_spmHistory[i] - _currentTargetSpm).abs() / _currentTargetSpm;
      totalDeviation += deviation;
      count++;
    }
    
    final avgDeviation = totalDeviation / count;
    
    // 偏差が小さいほど反応性が高い
    if (avgDeviation < 0.02) return 1.0;
    if (avgDeviation < 0.04) return 0.8;
    if (avgDeviation < 0.06) return 0.6;
    if (avgDeviation < 0.08) return 0.4;
    return 0.2;
  }
  
  /// 目標SPMの調整量を計算
  double _calculateAdjustment({
    required double currentSpm,
    required double stabilityScore,
    required double responsivenessScore,
    required double timeDelta,
  }) {
    // 現在の偏差
    final deviation = (currentSpm - _currentTargetSpm) / _currentTargetSpm;
    
    // 基本調整量
    double baseAdjustment = 0.0;
    
    // 無意識的な誘導のための微細な調整
    if (deviation.abs() < _comfortZoneRatio) {
      // 快適ゾーン内：ゆっくりと目標を上げる
      if (stabilityScore > 0.7 && responsivenessScore > 0.6) {
        baseAdjustment = _microAdjustmentRange * _currentTargetSpm * timeDelta;
        _stableWalkingDuration += (timeDelta * 1000).toInt();
        
        // 長時間安定している場合、わずかに増加率を上げる
        if (_stableWalkingDuration > 60000) { // 1分以上安定
          baseAdjustment *= 1.5;
        }
      }
    } else if (deviation > _comfortZoneRatio) {
      // 実際のSPMが高すぎる：目標を少し上げて追従
      baseAdjustment = deviation * 0.3 * _adaptationRate * _currentTargetSpm * timeDelta;
    } else {
      // 実際のSPMが低すぎる：目標を少し下げて合わせる
      baseAdjustment = deviation * 0.5 * _adaptationRate * _currentTargetSpm * timeDelta;
      _stableWalkingDuration = 0; // リセット
    }
    
    // 個人差を考慮した調整
    baseAdjustment *= _responsivenessScore;
    
    // 安定性を重視する場合は調整を抑える
    if (_stabilityPreference > 1.0) {
      baseAdjustment *= (2.0 - _stabilityPreference);
    }
    
    return baseAdjustment;
  }
  
  /// 履歴にデータを追加
  void _addToHistory(double spm, double cv) {
    _spmHistory.add(spm);
    _cvHistory.add(cv);
    
    // ウィンドウサイズを超えたら古いデータを削除
    if (_spmHistory.length > _historyWindowSize) {
      _spmHistory.removeAt(0);
    }
    if (_cvHistory.length > _historyWindowSize) {
      _cvHistory.removeAt(0);
    }
  }
  
  /// 個人パラメータを学習・更新
  void updatePersonalParameters({
    double? responsivenessScore,
    double? stabilityPreference,
    double? maxComfortableSpm,
  }) {
    if (responsivenessScore != null) {
      _responsivenessScore = responsivenessScore.clamp(0.5, 2.0);
    }
    if (stabilityPreference != null) {
      _stabilityPreference = stabilityPreference.clamp(0.5, 2.0);
    }
    if (maxComfortableSpm != null) {
      _maxComfortableSpm = maxComfortableSpm;
    }
  }
  
  /// 現在の制御状態を取得
  Map<String, dynamic> getControlStatus() {
    return {
      'baselineSpm': _baselineSpm,
      'currentTargetSpm': _currentTargetSpm,
      'maxComfortableSpm': _maxComfortableSpm,
      'stabilityScore': _evaluateStability(),
      'responsivenessScore': _evaluateResponsiveness(),
      'stableWalkingDuration': _stableWalkingDuration,
      'historyLength': _spmHistory.length,
    };
  }
  
  /// フェーズ3用の段階的増加モード
  double getNextIncreasedTarget() {
    // 現在の安定性に基づいて増加幅を決定
    final stabilityScore = _evaluateStability();
    double increaseStep = 5.0; // デフォルト
    
    if (stabilityScore > 0.8) {
      increaseStep = 5.0;
    } else if (stabilityScore > 0.6) {
      increaseStep = 3.0;
    } else {
      increaseStep = 2.0;
    }
    
    _currentTargetSpm += increaseStep;
    _stableWalkingDuration = 0; // リセット
    
    return _currentTargetSpm;
  }
  
  /// 実験セッションから個人パラメータを学習
  void learnFromSession(List<Map<String, dynamic>> sessionData) {
    if (sessionData.length < 30) return; // 十分なデータがない
    
    // 反応性の学習
    double totalResponseTime = 0;
    int responseCount = 0;
    
    for (int i = 1; i < sessionData.length; i++) {
      final prevData = sessionData[i - 1];
      final currData = sessionData[i];
      
      // メトロノームのテンポが変わった時点を検出
      if (prevData['targetSPM'] != currData['targetSPM']) {
        // 変化後のデータポイントを確認
        for (int j = i; j < math.min(i + 30, sessionData.length); j++) {
          final followRate = sessionData[j]['followRate'] as double?;
          if (followRate != null && followRate > 90) {
            // 90%以上の追従率に達するまでの時間
            responseCount++;
            totalResponseTime += (j - i);
            break;
          }
        }
      }
    }
    
    if (responseCount > 0) {
      final avgResponseTime = totalResponseTime / responseCount;
      // 反応時間が短いほど反応性スコアが高い
      if (avgResponseTime < 5) {
        _responsivenessScore = 1.5;
      } else if (avgResponseTime < 10) {
        _responsivenessScore = 1.2;
      } else if (avgResponseTime < 15) {
        _responsivenessScore = 1.0;
      } else {
        _responsivenessScore = 0.8;
      }
    }
    
    // 安定性重視度の学習
    double totalCv = 0;
    int cvCount = 0;
    
    for (final data in sessionData) {
      final cv = data['cv'] as double?;
      if (cv != null && cv > 0) {
        totalCv += cv;
        cvCount++;
      }
    }
    
    if (cvCount > 0) {
      final avgCv = totalCv / cvCount;
      // CV値が低いほど安定性を重視する傾向
      if (avgCv < 0.03) {
        _stabilityPreference = 1.5;
      } else if (avgCv < 0.05) {
        _stabilityPreference = 1.2;
      } else if (avgCv < 0.08) {
        _stabilityPreference = 1.0;
      } else {
        _stabilityPreference = 0.8;
      }
    }
    
    // 最大快適SPMの学習
    double maxStableSpm = _baselineSpm;
    
    for (final data in sessionData) {
      final spm = data['currentSPM'] as double?;
      final cv = data['cv'] as double?;
      
      if (spm != null && cv != null && cv < 0.05) {
        maxStableSpm = math.max(maxStableSpm, spm);
      }
    }
    
    _maxComfortableSpm = maxStableSpm * 1.1; // 10%のマージン
  }
  
  /// 個人パラメータをJSON形式で保存
  Map<String, dynamic> exportPersonalParameters() {
    return {
      'responsivenessScore': _responsivenessScore,
      'stabilityPreference': _stabilityPreference,
      'maxComfortableSpm': _maxComfortableSpm,
      'baselineSpm': _baselineSpm,
      'learningDate': DateTime.now().toIso8601String(),
    };
  }
  
  /// 保存された個人パラメータを読み込み
  void importPersonalParameters(Map<String, dynamic> params) {
    _responsivenessScore = (params['responsivenessScore'] ?? 1.0).toDouble();
    _stabilityPreference = (params['stabilityPreference'] ?? 1.0).toDouble();
    _maxComfortableSpm = (params['maxComfortableSpm'] ?? _baselineSpm * 1.15).toDouble();
  }
}

/// 変動係数（CV）計算用のユーティリティクラス
class GaitStabilityAnalyzer {
  /// ストライド間隔の変動係数を計算
  static double calculateCV(List<double> strideIntervals) {
    if (strideIntervals.length < 5) return 0.0;
    
    // 平均を計算
    final mean = strideIntervals.reduce((a, b) => a + b) / strideIntervals.length;
    
    // 標準偏差を計算
    double sumSquaredDiff = 0;
    for (final interval in strideIntervals) {
      sumSquaredDiff += math.pow(interval - mean, 2);
    }
    final stdDev = math.sqrt(sumSquaredDiff / strideIntervals.length);
    
    // CV = 標準偏差 / 平均
    return mean > 0 ? stdDev / mean : 0.0;
  }
  
  /// 歩行の対称性を評価（左右の歩幅の差）
  static double calculateSymmetry(List<double> leftSteps, List<double> rightSteps) {
    if (leftSteps.isEmpty || rightSteps.isEmpty) return 1.0;
    
    final minLength = math.min(leftSteps.length, rightSteps.length);
    double totalAsymmetry = 0;
    
    for (int i = 0; i < minLength; i++) {
      final asymmetry = (leftSteps[i] - rightSteps[i]).abs() / 
                       ((leftSteps[i] + rightSteps[i]) / 2);
      totalAsymmetry += asymmetry;
    }
    
    return 1.0 - (totalAsymmetry / minLength);
  }
}