import 'dart:math' as Math;
import 'package:collection/collection.dart'; // for List.sum, etc.

/// 右足側面センサー向けに最適化された歩行ピッチ検出アルゴリズム
class RightFootCadenceDetector {
  // 設定パラメータ
  final double windowSizeSeconds = 5.0; // 分析ウィンドウ
  final double updateFrequencyHz = 0.5; // 更新頻度 (2秒に1回)
  final double samplingRate = 50.0; // サンプリングレート
  final int historyMaxLength = 5; // BPM履歴長（安定性向上）

  // 内部バッファとカウンター
  List<Map<String, dynamic>> _sensorBuffer = [];
  List<double> _bpmHistory = [];
  int _sampleCounter = 0;

  // 結果変数
  double _lastBPM = 0.0;
  double _confidenceScore = 0.0;
  Map<String, dynamic> _lastDebugInfo = {};

  /// センサーデータ追加と処理
  /// 入力: M5SensorDataオブジェクトを想定
  Map<String, dynamic> addSensorData(dynamic sensorDataObject) {
    // Mapに変換（nullチェックを含む）
    Map<String, dynamic> sensorData = {
      'AccX': sensorDataObject.accX,
      'AccY': sensorDataObject.accY,
      'AccZ': sensorDataObject.accZ,
      'GyroX': sensorDataObject.gyroX,
      'GyroY': sensorDataObject.gyroY,
      'GyroZ': sensorDataObject.gyroZ,
      'timestamp': sensorDataObject.timestamp,
    };

    // バッファに追加
    _sensorBuffer.add(sensorData);
    _sampleCounter++;

    // バッファサイズ管理
    int windowSizeSamples = (windowSizeSeconds * samplingRate).round();
    if (_sensorBuffer.length > windowSizeSamples) {
      _sensorBuffer.removeAt(0);
    }

    // 更新間隔に達したらBPM計算
    int updateIntervalSamples = (1 / updateFrequencyHz * samplingRate).round();
    if (_sampleCounter >= updateIntervalSamples) {
      _calculateBPM();
      _sampleCounter = 0;
    }

    return {
      'bpm': _lastBPM,
      'confidence': _confidenceScore,
      'debug_info': _lastDebugInfo
    };
  }

  /// BPM計算
  void _calculateBPM() {
    if (_sensorBuffer.length <
        (windowSizeSeconds * samplingRate * 0.8).round()) {
      return; // データ不足
    }

    // センサーデータを抽出 (null許容型とデフォルト値0.0を使用)
    List<double> accX =
        _sensorBuffer.map((data) => (data['AccX'] as double?) ?? 0.0).toList();
    List<double> accY =
        _sensorBuffer.map((data) => (data['AccY'] as double?) ?? 0.0).toList();
    List<double> accZ =
        _sensorBuffer.map((data) => (data['AccZ'] as double?) ?? 0.0).toList();

    // 1. 右足接地特化信号の生成
    List<double> impactSignal = _createFootImpactSignal(accX, accY, accZ);

    // 2. ピーク検出による右足ステップ検出
    Map<String, dynamic> stepResult = _detectRightFootSteps(impactSignal);
    double rightFootBPM = stepResult['bpm'] ?? 0.0;
    double directConfidence = stepResult['confidence'] ?? 0.0;

    // 3. 周波数分析
    Map<String, dynamic> freqResult = _analyzeFrequency(impactSignal);
    double freqBPM = freqResult['bpm'] ?? 0.0;
    double freqConfidence = freqResult['confidence'] ?? 0.0;

    // 4. BPMの決定（明確なルールベース）
    Map<String, dynamic> finalResult = _determineFinalBPM(
        rightFootBPM, directConfidence, freqBPM, freqConfidence);

    double finalBPM = finalResult['bpm'] ?? 0.0;
    double finalConfidence = finalResult['confidence'] ?? 0.0;
    String method = finalResult['method'] ?? 'unknown';

    // デバッグ情報
    Map<String, dynamic> debugInfo = {
      'right_foot_bpm': rightFootBPM,
      'freq_bpm': freqBPM,
      'final_bpm': finalBPM,
      'method': method,
      'peaks': stepResult['peaks'],
      'intervals': stepResult['intervals'], // デバッグ用にインターバルも追加
      'autocorr': freqResult['debug_autocorr'], // 自己相関結果も追加
      'confidence': {
        'direct': directConfidence,
        'freq': freqConfidence,
        'final': finalConfidence
      }
    };

    // 結果が有効なら履歴に追加
    if (finalBPM > 0) {
      _bpmHistory.add(finalBPM);
      if (_bpmHistory.length > historyMaxLength) {
        _bpmHistory.removeAt(0);
      }

      // メディアンフィルタリング
      if (_bpmHistory.length >= 3) {
        List<double> sortedHistory = List<double>.from(_bpmHistory)..sort();
        double medianBPM = sortedHistory[_bpmHistory.length ~/ 2];

        _lastBPM = medianBPM;
        _confidenceScore = finalConfidence; // 最後の計算の信頼度を保持
        _lastDebugInfo = debugInfo; // デバッグ情報も更新

        debugInfo['history'] = List<double>.from(_bpmHistory);
        debugInfo['median_bpm'] = medianBPM;
      } else {
        _lastBPM = finalBPM;
        _confidenceScore = finalConfidence;
        _lastDebugInfo = debugInfo;
      }
    } else {
      // 有効なBPMが計算されなかった場合、履歴は更新せず、最終結果を0に維持
      // _lastBPM = 0.0; // 既に0のはずだが念のため
      // _confidenceScore = 0.0;
      _lastDebugInfo = debugInfo; // デバッグ情報は更新
    }
  }

  /// 右足接地検出に特化した信号を生成
  List<double> _createFootImpactSignal(
      List<double> accX, List<double> accY, List<double> accZ) {
    if (accX.isEmpty ||
        accX.length != accY.length ||
        accX.length != accZ.length) return [];

    // 差分信号（変化量）を計算
    List<double> xDiff = [];
    List<double> yDiff = [];
    List<double> zDiff = [];

    for (int i = 1; i < accX.length; i++) {
      xDiff.add((accX[i] - accX[i - 1]).abs());
      yDiff.add((accY[i] - accY[i - 1]).abs());
      zDiff.add((accZ[i] - accZ[i - 1]).abs());
    }

    // 複合信号生成 - 右足接地に合わせて最適化
    List<double> impactSignal = [];
    if (xDiff.isEmpty) return []; // 差分計算後もチェック

    for (int i = 0; i < xDiff.length; i++) {
      // 重要: 垂直方向(Y)を特に強調
      double impact = yDiff[i] * 4.0 + xDiff[i] * 1.0 + zDiff[i] * 1.5;
      impactSignal.add(impact);
    }

    // 移動平均による平滑化
    List<double> smoothed = [];
    int windowSize = 3; // 平滑化ウィンドウサイズ（片側）

    if (impactSignal.isEmpty) return [];

    for (int i = 0; i < impactSignal.length; i++) {
      double sum = 0;
      int count = 0;
      int start = Math.max(0, i - windowSize);
      int end = Math.min(impactSignal.length - 1, i + windowSize);

      for (int j = start; j <= end; j++) {
        sum += impactSignal[j];
        count++;
      }

      smoothed.add(count > 0 ? sum / count : 0.0);
    }

    return smoothed;
  }

  /// 右足ステップ検出
  Map<String, dynamic> _detectRightFootSteps(List<double> signal) {
    if (signal.length < 20) {
      // 最小サンプル数チェック
      return {'bpm': 0.0, 'confidence': 0.0, 'peaks': [], 'intervals': []};
    }
    // 統計情報の計算
    double mean = signal.average; // collection パッケージを使用
    double variance = signal.map((x) => Math.pow(x - mean, 2)).toList().average;
    double stdDev = Math.sqrt(variance);

    // 動的閾値設定
    double threshold = mean + stdDev * 1.8;

    // 右足歩行の間隔（40-75 BPM -> 0.8 - 1.5秒）
    int minDistance = (samplingRate * 0.8).round(); // 75 BPM に相当

    // ピーク検出
    List<int> peaks = [];
    for (int i = 1; i < signal.length - 1; i++) {
      if (signal[i] > threshold &&
          signal[i] > signal[i - 1] &&
          signal[i] > signal[i + 1]) {
        // 最小距離を確保
        if (peaks.isEmpty || (i - peaks.last) >= minDistance) {
          peaks.add(i);
        }
        // より強いピークで置き換え
        else if (signal[i] > signal[peaks.last]) {
          peaks[peaks.length - 1] = i;
        }
      }
    }

    // ピーク間隔からBPMを計算
    if (peaks.length < 2) {
      return {'bpm': 0.0, 'confidence': 0.0, 'peaks': peaks, 'intervals': []};
    }

    List<int> intervals = [];
    for (int i = 1; i < peaks.length; i++) {
      intervals.add(peaks[i] - peaks[i - 1]);
    }

    if (intervals.isEmpty) {
      return {'bpm': 0.0, 'confidence': 0.0, 'peaks': peaks, 'intervals': []};
    }

    // 外れ値の除外
    double avgInterval = intervals.average;
    List<int> filteredIntervals = intervals
        .where((interval) =>
            interval > avgInterval * 0.7 && interval < avgInterval * 1.3)
        .toList();

    if (filteredIntervals.isEmpty) {
      return {'bpm': 0.0, 'confidence': 0.0, 'peaks': peaks, 'intervals': []};
    }

    // 中央値の計算
    filteredIntervals.sort();
    double medianInterval = filteredIntervals.length % 2 == 0
        ? (filteredIntervals[filteredIntervals.length ~/ 2 - 1] +
                filteredIntervals[filteredIntervals.length ~/ 2]) /
            2.0
        : filteredIntervals[filteredIntervals.length ~/ 2].toDouble();

    // 右足のBPM計算
    if (medianInterval <= 0) {
      // ゼロ除算防止
      return {
        'bpm': 0.0,
        'confidence': 0.0,
        'peaks': peaks,
        'intervals': filteredIntervals
      };
    }
    double rightFootBPM = 60.0 * samplingRate / medianInterval;

    // 信頼度計算
    double intervalConsistency = filteredIntervals.length / intervals.length;
    double peakCountFactor = Math.min(1.0, peaks.length / 6.0); // 6ステップ以上で最大
    double confidence = Math.min(1.0, intervalConsistency * peakCountFactor);

    // 範囲外BPMのペナルティ
    if (rightFootBPM < 30 || rightFootBPM > 90) {
      // 右足単独として広めの範囲
      confidence *= 0.5;
    }

    return {
      'bpm': rightFootBPM,
      'confidence': confidence,
      'peaks': peaks,
      'intervals': filteredIntervals // デバッグ用
    };
  }

  /// 周波数分析 (自己相関法)
  Map<String, dynamic> _analyzeFrequency(List<double> signal) {
    if (signal.length < samplingRate * 2) {
      // 最低2秒分のデータが必要
      return {
        'bpm': 0.0,
        'confidence': 0.0,
        'right_foot_bpm': 0.0,
        'full_gait_bpm': 0.0,
        'debug_autocorr': []
      };
    }

    // データの中心化
    double mean = signal.average;
    List<double> centered = signal.map((x) => x - mean).toList();

    // 周波数分析（自己相関法）
    int maxLag = Math.min(
        (samplingRate * 2).round(), centered.length - 1); // 最大2秒のラグ、配列長を超えない
    List<double> autocorr = List.filled(maxLag + 1, 0.0);

    for (int lag = 0; lag <= maxLag; lag++) {
      double sum = 0;
      for (int i = 0; i < centered.length - lag; i++) {
        sum += centered[i] * centered[i + lag];
      }
      // count > 0 を確認する代わりに、常に centered.length - lag で割る（論文等で一般的な定義）
      if (centered.length - lag > 0) {
        autocorr[lag] = sum / (centered.length - lag);
      }
    }

    // 正規化（ラグ0の値で割る）
    double maxVal = autocorr[0];
    if (maxVal <= 0) {
      // ゼロ除算防止
      return {
        'bpm': 0.0,
        'confidence': 0.0,
        'right_foot_bpm': 0.0,
        'full_gait_bpm': 0.0,
        'debug_autocorr': []
      };
    }
    List<double> normalizedAutocorr = autocorr.map((x) => x / maxVal).toList();

    // 右足ステップ周波数範囲（30-75 BPM）と全体歩行周波数範囲（60-150 BPM）
    int minLagRightFoot = (samplingRate * 60.0 / 75.0).round();
    int maxLagRightFoot = (samplingRate * 60.0 / 30.0).round();
    int minLagFullGait = (samplingRate * 60.0 / 150.0).round();
    int maxLagFullGait = (samplingRate * 60.0 / 60.0).round();

    double rightFootBPM = 0.0;
    double rightFootConfidence = 0.0;
    int bestLagRight = 0;

    // 右足ステップBPM検出
    for (int lag = minLagRightFoot;
        lag <= maxLagRightFoot && lag < normalizedAutocorr.length;
        lag++) {
      // ピーク検出条件: 前後より大きく、最小閾値(0.2)を超える
      if (lag > 1 &&
          lag < normalizedAutocorr.length - 1 &&
          normalizedAutocorr[lag] > normalizedAutocorr[lag - 1] &&
          normalizedAutocorr[lag] > normalizedAutocorr[lag + 1] &&
          normalizedAutocorr[lag] > 0.2) {
        // 最も強いピークを採用
        if (normalizedAutocorr[lag] > rightFootConfidence) {
          rightFootConfidence = normalizedAutocorr[lag];
          bestLagRight = lag;
        }
      }
    }
    if (bestLagRight > 0) {
      rightFootBPM = 60.0 * samplingRate / bestLagRight;
    }

    double fullGaitBPM = 0.0;
    double fullGaitConfidence = 0.0;
    int bestLagFull = 0;

    // 全体歩行BPM検出
    for (int lag = minLagFullGait;
        lag <= maxLagFullGait && lag < normalizedAutocorr.length;
        lag++) {
      if (lag > 1 &&
          lag < normalizedAutocorr.length - 1 &&
          normalizedAutocorr[lag] > normalizedAutocorr[lag - 1] &&
          normalizedAutocorr[lag] > normalizedAutocorr[lag + 1] &&
          normalizedAutocorr[lag] > 0.2) {
        if (normalizedAutocorr[lag] > fullGaitConfidence) {
          fullGaitConfidence = normalizedAutocorr[lag];
          bestLagFull = lag;
        }
      }
    }
    if (bestLagFull > 0) {
      fullGaitBPM = 60.0 * samplingRate / bestLagFull;
    }

    // 結果の評価と最終BPM/信頼度の決定
    double finalBPM = 0.0;
    double finalConfidence = 0.0;

    // 優先順位:
    // 1. 全体歩行BPMが強く検出された場合 (90-130 BPM)
    // 2. 右足BPMが強く検出された場合 (45-65 BPM) -> 2倍する
    // 3. その他の検出結果 (信頼度を下げて採用)

    if (fullGaitBPM >= 90 && fullGaitBPM <= 130 && fullGaitConfidence > 0.3) {
      finalBPM = fullGaitBPM;
      finalConfidence = fullGaitConfidence;
    } else if (rightFootBPM >= 45 &&
        rightFootBPM <= 65 &&
        rightFootConfidence > 0.3) {
      finalBPM = rightFootBPM * 2;
      finalConfidence = rightFootConfidence;
    } else if (fullGaitConfidence > rightFootConfidence && fullGaitBPM > 0) {
      finalBPM = fullGaitBPM;
      finalConfidence = fullGaitConfidence * 0.8; // 信頼度少し減
    } else if (rightFootConfidence > 0 && rightFootBPM > 0) {
      // 範囲外の右足BPMでも、とりあえず2倍してみる価値はあるか？
      // ただし信頼度は下げる
      finalBPM = rightFootBPM * 2;
      finalConfidence = rightFootConfidence * 0.7;
    }

    return {
      'bpm': finalBPM,
      'confidence': Math.min(1.0, finalConfidence), // 1.0 を超えないように
      'right_foot_bpm': rightFootBPM,
      'full_gait_bpm': fullGaitBPM,
      'debug_autocorr': normalizedAutocorr // デバッグ用に自己相関結果を追加
    };
  }

  /// 最終的なBPM決定ルール
  Map<String, dynamic> _determineFinalBPM(double rightFootBPM,
      double directConfidence, double freqBPM, double freqConfidence) {
    // ルール 0: どちらの方法でも検出失敗 (信頼度低い場合も含む)
    if (directConfidence <= 0.2 && freqConfidence <= 0.2) {
      return {
        'bpm': 0.0,
        'confidence': 0.0,
        'method': 'no_detection_low_confidence'
      };
    }

    // ルール 1: 直接検出の信頼度が高く、BPMが妥当な範囲 (右足40-70)
    if (directConfidence >= 0.5 && (rightFootBPM >= 40 && rightFootBPM <= 70)) {
      double bpmToUse = rightFootBPM * 2;
      double confidence = directConfidence;
      String method = 'direct_doubled';
      // 周波数分析結果と大きく乖離していないか確認
      if (freqBPM > 0 &&
          (bpmToUse / freqBPM < 0.8 || bpmToUse / freqBPM > 1.2)) {
        confidence *= 0.7; // 大きく乖離 -> 信頼度を下げる
        method += '_freq_mismatch';
      }
      return {
        'bpm': bpmToUse,
        'confidence': Math.min(1.0, confidence),
        'method': method
      };
    }
    // ルール 1.1: 直接検出の信頼度が高く、BPMが妥当な全体範囲 (80-140)
    else if (directConfidence >= 0.5 &&
        (rightFootBPM >= 80 && rightFootBPM <= 140)) {
      double bpmToUse = rightFootBPM;
      double confidence = directConfidence;
      String method = 'direct_valid_range';
      if (freqBPM > 0 &&
          (bpmToUse / freqBPM < 0.8 || bpmToUse / freqBPM > 1.2)) {
        confidence *= 0.7;
        method += '_freq_mismatch';
      }
      return {
        'bpm': bpmToUse,
        'confidence': Math.min(1.0, confidence),
        'method': method
      };
    }

    // ルール 2: 周波数分析の信頼度が高く、BPMが妥当な範囲 (90-130)
    if (freqConfidence >= 0.5 && (freqBPM >= 90 && freqBPM <= 130)) {
      double bpmToUse = freqBPM;
      double confidence = freqConfidence;
      String method = 'frequency_strong';
      // 直接検出結果と比較 (右足BPMなら2倍して比較)
      double directBpmComparable = (rightFootBPM >= 40 && rightFootBPM <= 70)
          ? rightFootBPM * 2
          : rightFootBPM;
      if (rightFootBPM > 0 &&
          (bpmToUse / directBpmComparable < 0.8 ||
              bpmToUse / directBpmComparable > 1.2)) {
        confidence *= 0.7;
        method += '_direct_mismatch';
      }
      return {
        'bpm': bpmToUse,
        'confidence': Math.min(1.0, confidence),
        'method': method
      };
    }

    // ルール 3: どちらかの信頼度が高い方を採用 (より詳細なフォールバック)
    if (directConfidence > freqConfidence) {
      // 直接検出を優先
      double bpmToUse;
      double confidence = directConfidence;
      String method;
      if (rightFootBPM >= 40 && rightFootBPM <= 70) {
        bpmToUse = rightFootBPM * 2;
        method = 'direct_dominant_doubled';
      } else if (rightFootBPM >= 80 && rightFootBPM <= 140) {
        bpmToUse = rightFootBPM;
        method = 'direct_dominant_valid';
      } else if (rightFootBPM < 40 && rightFootBPM > 0) {
        // 低すぎる場合
        bpmToUse = rightFootBPM * 2;
        confidence *= 0.6;
        method = 'direct_dominant_too_low_doubled';
      } else if (rightFootBPM > 140) {
        // 高すぎる場合
        bpmToUse = rightFootBPM; // 高すぎる場合はそのまま？ or 半分？ -> 一旦そのまま採用し信頼度↓
        confidence *= 0.6;
        method = 'direct_dominant_too_high';
      } else {
        // 70-80 の隙間など
        bpmToUse = rightFootBPM; // とりあえずそのまま
        confidence *= 0.5;
        method = 'direct_dominant_gap_range';
      }
      return {
        'bpm': bpmToUse,
        'confidence': Math.min(1.0, confidence),
        'method': method
      };
    } else if (freqConfidence > 0) {
      // freqConfidence >= directConfidence と同義
      double bpmToUse = freqBPM;
      double confidence = freqConfidence;
      String method = 'frequency_dominant';
      if (freqBPM < 80 || freqBPM > 140) {
        // 周波数分析の妥当範囲を80-140に
        confidence *= 0.6;
        method += '_range_penalty';
      }
      return {
        'bpm': bpmToUse,
        'confidence': Math.min(1.0, confidence),
        'method': method
      };
    }

    // フォールバック（ここには到達しないはず）
    return {'bpm': 0.0, 'confidence': 0.0, 'method': 'fallback_error'};
  }

  /// 内部状態をリセット
  void reset() {
    _sensorBuffer.clear();
    _bpmHistory.clear();
    _sampleCounter = 0;
    _lastBPM = 0.0;
    _confidenceScore = 0.0;
    _lastDebugInfo = {};
    print("RightFootCadenceDetector reset.");
  }
}
