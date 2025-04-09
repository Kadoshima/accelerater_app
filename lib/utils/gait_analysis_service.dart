import 'dart:collection';
import 'dart:math' as math;
import '../models/sensor_data.dart';

/// 足首センサーデータから歩行ステップとピッチ(SPM)を検出するサービス
/// FFT（高速フーリエ変換）を使用した周波数解析方式
class GaitAnalysisService {
  // --- FFT解析のパラメータ ---
  final int totalDataSeconds; // 全体のデータバッファ長（秒）
  final int windowSizeSeconds; // FFT処理するウィンドウサイズ（秒）
  final int slideIntervalSeconds; // スライド間隔（秒）
  final double minFrequency; // 歩行と見なす最小周波数 (Hz)
  final double maxFrequency; // 歩行と見なす最大周波数 (Hz)
  final double minSpm; // 最小SPM (40 = 非常にゆっくりした歩行)
  final double maxSpm; // 最大SPM (180 = 非常に速い走り)
  final double smoothingFactor; // 結果の平滑化係数 (0.0-1.0)
  final double minReliability; // 最小信頼度しきい値 (0.0-1.0)
  final double staticThreshold; // 静止判定の閾値（加速度の標準偏差）
  final bool useSingleAxisOnly; // 単一軸のみを使用するか
  final String verticalAxis; // 垂直方向に相当する軸 ('x', 'y', 'z')

  // --- 内部変数 ---
  final Queue<M5SensorData> _dataBuffer; // センサーデータバッファ
  double _currentSpm = 0.0; // 現在の歩行ピッチ
  double _reliability = 0.0; // 検出の信頼度
  int _stepCount = 0; // 累計ステップ数
  int _lastProcessingTime = 0; // 最後の処理時間
  int _samplingRate = 60; // サンプリングレートを60Hzに固定
  final List<double> _recentFrequencies = []; // 最近検出した周波数
  final List<double> _fftMagnitudes = []; // デバッグ用FFT振幅値

  // --- ゲッター ---
  int get stepCount => _stepCount;
  double get currentSpm => _currentSpm;
  double get reliability => _reliability;
  List<double> get fftMagnitudes => List.unmodifiable(_fftMagnitudes); // デバッグ用

  /// コンストラクタ
  GaitAnalysisService({
    this.totalDataSeconds = 25, // 25秒分のデータを保持（ウィンドウサイズに合わせて増加）
    this.windowSizeSeconds = 15, // 15秒のウィンドウでFFT計算（最大精度優先）
    this.slideIntervalSeconds = 1, // 1秒ごとにスライド
    this.minFrequency = 1.0, // 最小周波数 1.0Hz (60 SPM)
    this.maxFrequency = 2.67, // 最大周波数 2.67Hz (160 SPM)
    this.minSpm = 60.0, // 最小SPM (60 = ゆっくりした歩行)
    this.maxSpm = 160.0, // 最大SPM (160 = 速い歩行)
    this.smoothingFactor = 0.2, // 平滑化係数（反応性向上のため0.1から0.2に変更）
    this.minReliability = 0.25, // 最小信頼度 (25%)
    this.staticThreshold = 0.03, // 静止判定の閾値 (0.03G)
    this.useSingleAxisOnly = true, // 単一軸のみを使用
    this.verticalAxis = 'x', // 垂直方向の軸（デバイスが横置きならX軸）
  }) : _dataBuffer = Queue<M5SensorData>() {
    print('GaitAnalysisService初期化(FFT方式): '
        'バッファ=${totalDataSeconds}秒, '
        'ウィンドウ=${windowSizeSeconds}秒, '
        'スライド=${slideIntervalSeconds}秒, '
        'サンプリングレート=60Hz固定, '
        '周波数範囲=${minFrequency}Hz-${maxFrequency}Hz, '
        '信頼度閾値=${(minReliability * 100).toStringAsFixed(0)}%, '
        '静止閾値=${staticThreshold}G, '
        '垂直軸=${verticalAxis}, '
        '単一軸のみ使用=${useSingleAxisOnly}');
  }

  /// 新しいセンサーデータを処理
  void addSensorData(M5SensorData sensorData) {
    // バッファにデータを追加
    _dataBuffer.add(sensorData);

    // サンプリングレートの推定（初期または定期的に）
    _updateSamplingRate();

    // バッファサイズの制限（推定サンプリングレートに基づいて）
    int maxBufferSize = totalDataSeconds * _samplingRate;
    while (_dataBuffer.length > maxBufferSize) {
      _dataBuffer.removeFirst();
    }

    // 処理間隔をチェック（スライド間隔秒ごとに処理）
    int currentTime = sensorData.timestamp;
    if (_lastProcessingTime == 0 ||
        (currentTime - _lastProcessingTime) >= slideIntervalSeconds * 1000) {
      // FFT処理を実行
      _processFFT();
      _lastProcessingTime = currentTime;
    }
  }

  /// サンプリングレートの推定（タイムスタンプから計算）
  void _updateSamplingRate() {
    // サンプリングレートを60Hzに固定
    _samplingRate = 60;

    // デバッグ用に実際のサンプリングレートを計算して表示するだけ
    if (_dataBuffer.length < 10) return; // データが少なすぎる

    // 最初と最後のタイムスタンプから平均サンプリングレートを計算
    int firstTime = _dataBuffer.first.timestamp;
    int lastTime = _dataBuffer.last.timestamp;
    double durationSeconds = (lastTime - firstTime) / 1000.0;

    if (durationSeconds > 0) {
      int estimatedRate = ((_dataBuffer.length - 1) / durationSeconds).round();

      // 実際のサンプリングレートをログ出力（参考情報として）
      // print(
      //     '実際のサンプリングレート: ${estimatedRate}Hz (データ数: ${_dataBuffer.length}, 期間: ${durationSeconds.toStringAsFixed(2)}秒)');
      // print('固定サンプリングレート60Hzを使用中');
    }
  }

  /// センサーの指定された軸の値を取得
  double _getAxisValue(M5SensorData data, String axis) {
    switch (axis.toLowerCase()) {
      case 'x':
        return data.accX ?? 0.0;
      case 'y':
        return data.accY ?? 0.0;
      case 'z':
        return data.accZ ?? 0.0;
      default:
        return 0.0;
    }
  }

  /// FFT処理メイン
  void _processFFT() {
    if (_dataBuffer.length < windowSizeSeconds * _samplingRate) {
      print(
          'FFT: データ不足 (${_dataBuffer.length}/${windowSizeSeconds * _samplingRate})');
      return;
    }

    print(
        'FFT処理実行: サンプリングレート=${_samplingRate}Hz, バッファサイズ=${_dataBuffer.length}');

    // 最新のウィンドウサイズ分のデータを抽出
    int windowSamples = windowSizeSeconds * _samplingRate;
    List<double> windowData = [];

    // バッファの後ろからwindowSamples分のデータを取得
    List<M5SensorData> recentData =
        _dataBuffer.toList().sublist(_dataBuffer.length - windowSamples);

    // 静止状態の判定
    bool isStatic = _checkIfStatic(recentData);
    if (isStatic) {
      print('FFT: 静止状態検出 - スキップ');
      // 静止状態ならSPMを0にリセット
      if (_currentSpm > 0) {
        print('FFT: 静止状態検出 - SPMリセット');
        _currentSpm = 0.0;
        _reliability = 0.0;
      }
      return;
    }

    // センサーデータの取得（指定軸のみか合成加速度か）
    for (var data in recentData) {
      if (useSingleAxisOnly) {
        // 指定軸のデータのみを使用（通常は垂直方向）
        windowData.add(_getAxisValue(data, verticalAxis));
      } else {
        // 合成加速度を使用（全方向の動きを考慮）
        windowData.add(data.magnitude ?? 0.0);
      }
    }

    // 前処理（トレンド除去とハミング窓適用）
    List<double> processedData = _preprocessData(windowData);

    // FFT実行
    List<_Complex> fftResult = _computeFFT(processedData);

    // FFT結果から周波数スペクトル計算
    List<double> magnitudes = _computeMagnitudes(fftResult);
    _fftMagnitudes.clear();
    _fftMagnitudes.addAll(magnitudes);

    // 周波数ピーク検出
    double peakFrequency = _findPeakFrequency(magnitudes);

    // 信頼度の計算（最大値と全体の比率から）
    double reliability = _calculateReliability(magnitudes, peakFrequency);

    // 信頼度が低いピークは無視
    if (reliability < minReliability) {
      print(
          'FFT: 信頼度不足 (${(reliability * 100).toStringAsFixed(1)}% < ${(minReliability * 100).toStringAsFixed(1)}%) - スキップ');
      return;
    }

    // 周波数からSPMへの変換
    if (peakFrequency > 0) {
      // 周波数をSPMに変換 (Hz * 60 = SPM)
      double newSpm = peakFrequency * 60.0;

      // SPMを現実的な範囲に制限
      if (newSpm < minSpm) {
        print('FFT: 下限値を適用: $newSpm → $minSpm');
        newSpm = minSpm;
      } else if (newSpm > maxSpm) {
        print('FFT: 上限値を適用: $newSpm → $maxSpm');
        newSpm = maxSpm;
      }

      _recentFrequencies.add(peakFrequency);
      // 最大10個の周波数を保持
      if (_recentFrequencies.length > 10) {
        _recentFrequencies.removeAt(0);
      }

      // SPM更新（平滑化）
      double previousSpm = _currentSpm;
      if (_currentSpm <= 0) {
        _currentSpm = newSpm; // 初回は平滑化なし
      } else {
        _currentSpm =
            (1 - smoothingFactor) * _currentSpm + smoothingFactor * newSpm;
      }

      _reliability = reliability;

      // ステップ数の更新（周波数 * 経過時間）
      double elapsedTimeSinceLastProcess = slideIntervalSeconds.toDouble();
      int newSteps = (peakFrequency * elapsedTimeSinceLastProcess).round();
      _stepCount += newSteps;

      print('FFT: SPM更新 $previousSpm → ${_currentSpm.toStringAsFixed(1)} '
          '(周波数=${peakFrequency.toStringAsFixed(2)}Hz, '
          '信頼度=${(_reliability * 100).toStringAsFixed(1)}%, '
          'ステップ+$newSteps)');
    } else {
      // ピークが見つからない場合
      print('FFT: 有効な周波数ピークなし');

      // 静止状態と判断し、SPMをゼロにリセット
      if (_currentSpm > 0) {
        print('FFT: 静止状態検出 - SPMリセット');
        _currentSpm = 0.0;
        _reliability = 0.0;
      }
    }
  }

  /// 静止状態かどうかをチェック
  bool _checkIfStatic(List<M5SensorData> data) {
    if (data.isEmpty) return true;

    // 垂直方向の加速度の標準偏差を計算
    List<double> accValues = [];
    for (var item in data) {
      double axisValue = _getAxisValue(item, verticalAxis);
      accValues.add(axisValue);
    }

    if (accValues.isEmpty) return true;

    // 平均値
    double mean = accValues.reduce((a, b) => a + b) / accValues.length;

    // 標準偏差
    double sumSquaredDiff = 0;
    for (var val in accValues) {
      double diff = val - mean;
      sumSquaredDiff += diff * diff;
    }
    double stdDev = math.sqrt(sumSquaredDiff / accValues.length);

    // 標準偏差が閾値未満なら静止状態と判断
    bool isStatic = stdDev < staticThreshold;
    if (isStatic) {
      print('静止状態検出: 標準偏差=$stdDev < 閾値=$staticThreshold');
    }
    return isStatic;
  }

  /// データの前処理（トレンド除去とハミング窓適用）
  List<double> _preprocessData(List<double> data) {
    // トレンド除去（平均値を引く）
    double mean = data.reduce((a, b) => a + b) / data.length;
    List<double> detrended = data.map((x) => x - mean).toList();

    // ハミング窓の適用（エッジ効果を減らすため）
    List<double> windowed = List<double>.filled(detrended.length, 0.0);
    for (int i = 0; i < detrended.length; i++) {
      // ハミング窓の計算: 0.54 - 0.46 * cos(2πi/(N-1))
      double window =
          0.54 - 0.46 * math.cos(2 * math.pi * i / (detrended.length - 1));
      windowed[i] = detrended[i] * window;
    }

    return windowed;
  }

  /// FFT計算（複素数FFT）
  List<_Complex> _computeFFT(List<double> data) {
    // 入力データサイズを2のべき乗に調整
    int n = 1;
    while (n < data.length) {
      n *= 2;
    }

    // ゼロパディング
    List<_Complex> complexData = List<_Complex>.filled(n, _Complex(0, 0));
    for (int i = 0; i < data.length; i++) {
      complexData[i] = _Complex(data[i], 0);
    }

    // FFT実行
    return _fft(complexData);
  }

  /// 再帰的FFTアルゴリズム
  List<_Complex> _fft(List<_Complex> x) {
    int n = x.length;

    // 基底ケース
    if (n == 1) return [x[0]];

    // 奇数・偶数インデックスに分割
    List<_Complex> even = List<_Complex>.filled(n ~/ 2, _Complex(0, 0));
    List<_Complex> odd = List<_Complex>.filled(n ~/ 2, _Complex(0, 0));

    for (int i = 0; i < n ~/ 2; i++) {
      even[i] = x[i * 2];
      odd[i] = x[i * 2 + 1];
    }

    // 再帰的に変換
    List<_Complex> evenResult = _fft(even);
    List<_Complex> oddResult = _fft(odd);

    // 結合
    List<_Complex> result = List<_Complex>.filled(n, _Complex(0, 0));
    for (int k = 0; k < n ~/ 2; k++) {
      double angle = -2 * math.pi * k / n;
      _Complex factor = _Complex(math.cos(angle), math.sin(angle));

      _Complex t = oddResult[k] * factor;
      result[k] = evenResult[k] + t;
      result[k + n ~/ 2] = evenResult[k] - t;
    }

    return result;
  }

  /// FFT結果から振幅計算
  List<double> _computeMagnitudes(List<_Complex> fftResult) {
    int n = fftResult.length;
    // ナイキスト周波数までの半分のみ使用
    int usefulBins = n ~/ 2;

    List<double> magnitudes = List<double>.filled(usefulBins, 0.0);
    for (int i = 0; i < usefulBins; i++) {
      // 振幅の計算（複素数の絶対値）
      magnitudes[i] = fftResult[i].magnitude;
    }

    return magnitudes;
  }

  /// 絶対値を計算する内部ヘルパー関数（math.abs代替）
  double _abs(double value) {
    return value < 0 ? -value : value;
  }

  /// 周波数ピークの検出（高速歩行時の問題対応）
  double _findPeakFrequency(List<double> magnitudes) {
    int n = magnitudes.length;

    // 歩行周波数範囲内のピークを探す（通常の全周波数範囲）
    int minBin = (minFrequency * windowSizeSeconds).round();
    int maxBin = (maxFrequency * windowSizeSeconds).round();

    // 範囲の調整
    minBin = math.max(1, minBin); // 0より大きい（DCは除外）
    maxBin = math.min(n - 1, maxBin); // 配列範囲内

    // ピーク候補を保存するための変数
    List<_FrequencyPeak> peaks = [];

    // 周波数スペクトルからすべての局所的ピークを検出
    for (int i = minBin + 1; i < maxBin - 1; i++) {
      // 局所的なピーク（両隣より大きい値）を検出
      if (magnitudes[i] > magnitudes[i - 1] &&
          magnitudes[i] > magnitudes[i + 1]) {
        double freq = i / windowSizeSeconds.toDouble();
        double amplitude = magnitudes[i];

        // 平均振幅の計算（ノイズレベル推定用）
        double localMean = 0.0;
        int sampleCount = 0;
        for (int j = math.max(minBin, i - 5);
            j <= math.min(maxBin, i + 5);
            j++) {
          if (j != i) {
            // ピーク自体は除外
            localMean += magnitudes[j];
            sampleCount++;
          }
        }
        localMean = localMean / sampleCount;

        // SNR計算（信号対ノイズ比）
        double snr = amplitude / (localMean + 0.001); // ゼロ除算防止

        // 閾値の引き上げ - SNRがある程度高いピークのみを追加
        if (snr > 1.5) {
          // SNR閾値を1.8から1.5に緩和
          peaks.add(_FrequencyPeak(freq, amplitude, snr));
        }
      }
    }

    // ピークが見つからない場合
    if (peaks.isEmpty) {
      return 0.0;
    }

    // 前回の検出周波数を取得（安定性向上のため）
    double? previousFreq =
        _recentFrequencies.isNotEmpty ? _recentFrequencies.last : null;

    // 前回の周波数の移動平均を計算（より安定した参照点）
    double recentAvgFreq = 0.0;
    if (_recentFrequencies.isNotEmpty) {
      // 直近3回分のデータの平均を使用
      int samplesToUse = math.min(3, _recentFrequencies.length);
      double sum = 0.0;
      for (int i = _recentFrequencies.length - samplesToUse;
          i < _recentFrequencies.length;
          i++) {
        sum += _recentFrequencies[i];
      }
      recentAvgFreq = sum / samplesToUse;
    }

    // 倍数関係のチェック用の閾値（許容誤差）
    const double freqRatioTolerance = 0.12; // 12%誤差許容（少し厳しくした）

    // ピークをSNRでソート（信号品質重視）
    peaks.sort((a, b) => b.snr.compareTo(a.snr));

    // SNRが最も高いピークを最初に考慮する（振幅よりも信号品質を重視）
    double bestPeakFreq = peaks[0].frequency;

    // 過去のデータがある場合、一貫性をチェック
    if (recentAvgFreq > 0) {
      // 最新の周波数候補と過去の平均との差
      double freqDiff = _abs(bestPeakFreq - recentAvgFreq);
      double relDiff = freqDiff / recentAvgFreq;

      // もし最も強いピークが過去の平均から大きく外れていたら
      if (relDiff > 0.20) {
        // 周波数一貫性判定の閾値を25%から20%に調整
        print(
            '大きな周波数変化を検出: ${recentAvgFreq.toStringAsFixed(2)}Hz → ${bestPeakFreq.toStringAsFixed(2)}Hz (${(relDiff * 100).toStringAsFixed(1)}% 変化)');

        // 他のピークが過去の周波数に近いものがないか探す
        for (var peak in peaks.skip(1)) {
          double peakRelDiff =
              _abs(peak.frequency - recentAvgFreq) / recentAvgFreq;

          // より一貫性のあるピークが見つかった場合
          if (peakRelDiff < 0.15 && peak.snr > peaks[0].snr * 0.7) {
            print(
                'より一貫性のあるピークを採用: ${bestPeakFreq.toStringAsFixed(2)}Hz → ${peak.frequency.toStringAsFixed(2)}Hz');
            bestPeakFreq = peak.frequency;
            break;
          }
        }
      }
    }

    // 分数調波の検出と修正（特に120 rpmが85 rpmとして誤検出される問題対応）
    double potentialHighFreq = bestPeakFreq;

    // 分数調波の検出：特に2/3倍周波数（120rpmと~80rpm）
    for (var peak in peaks) {
      // メインピークと他のピークの比率計算
      if (peak.frequency < potentialHighFreq) {
        double ratio = potentialHighFreq / peak.frequency;

        // 特に注意すべき比率範囲 (1.4-1.5の範囲は2/3分数調波の可能性)
        if (ratio >= 1.35 && ratio <= 1.55 && peak.snr > peaks[0].snr * 0.6) {
          print(
              '分数調波関係を検出: ${potentialHighFreq.toStringAsFixed(2)}Hz / ${peak.frequency.toStringAsFixed(2)}Hz = ${ratio.toStringAsFixed(2)}');

          // 分数調波の場合、より高い周波数を優先する
          // 実際のステップは低周波よりも高周波に対応することが多い
          print(
              '高周波を優先: ${potentialHighFreq.toStringAsFixed(2)}Hz (${(potentialHighFreq * 60).toStringAsFixed(1)} SPM) を採用');
          return potentialHighFreq;
        }
      }
    }

    // 高調波関係のチェックを強化（110rpmが150rpmと誤検出される問題に対応）
    double mainPeakFreq = bestPeakFreq;

    // 1.25倍から1.5倍の範囲に強いピークがあるかチェック（110rpmの1.36倍が150rpm）
    for (var peak in peaks) {
      double ratio = peak.frequency / mainPeakFreq;

      // 比率が約1.3-1.4倍の強いピークがある場合、誤検出の可能性
      if (ratio > 1.25 && ratio < 1.5 && peak.snr > peaks[0].snr * 0.8) {
        // このような場合、より低い周波数を採用
        print(
            '高調波関係を検出: ${peak.frequency.toStringAsFixed(2)}Hz と ${mainPeakFreq.toStringAsFixed(2)}Hz');

        // より低い周波数を採用
        if (mainPeakFreq < peak.frequency) {
          print('低周波を優先: ${mainPeakFreq.toStringAsFixed(2)}Hz を採用');
          return mainPeakFreq;
        } else {
          print('低周波を優先: ${peak.frequency.toStringAsFixed(2)}Hz を採用');
          return peak.frequency;
        }
      }
    }

    // 歩行速度の急激な加速・減速の検出（RPMレンジチェック）
    if (recentAvgFreq > 0 && _recentFrequencies.length >= 3) {
      // 予測範囲の計算（±20%）
      double expectedFreqMin = recentAvgFreq * 0.8;
      double expectedFreqMax = recentAvgFreq * 1.2;

      // 選択されたピークが予測範囲から大きく外れている場合
      if (bestPeakFreq < expectedFreqMin || bestPeakFreq > expectedFreqMax) {
        print(
            '検出周波数が予測範囲外: ${bestPeakFreq.toStringAsFixed(2)}Hz (予測範囲: ${expectedFreqMin.toStringAsFixed(2)}-${expectedFreqMax.toStringAsFixed(2)}Hz)');

        // 直前のデータと近い周波数のピークを探す
        for (var peak in peaks) {
          if (peak.frequency >= expectedFreqMin &&
              peak.frequency <= expectedFreqMax &&
              peak.snr > peaks[0].snr * 0.5) {
            print('予測範囲内のピークを採用: ${peak.frequency.toStringAsFixed(2)}Hz');
            bestPeakFreq = peak.frequency;
            break;
          }
        }
      }
    }

    return bestPeakFreq;
  }

  /// 信頼度の計算
  double _calculateReliability(List<double> magnitudes, double peakFrequency) {
    if (magnitudes.isEmpty) return 0.0;

    // ピークのインデックスを計算
    int peakIndex = (peakFrequency * windowSizeSeconds).round();
    if (peakIndex <= 0 || peakIndex >= magnitudes.length) {
      return 0.0;
    }

    // ピーク値
    double peakValue = magnitudes[peakIndex];

    // 平均値
    double meanValue = magnitudes.reduce((a, b) => a + b) / magnitudes.length;

    // ピーク値と平均値の比率に基づく信頼度
    double snRatio = (peakValue / (meanValue + 0.001)); // ゼロ除算防止

    // [0, 1]の範囲に正規化
    return math.min(1.0, snRatio / 5.0); // 比率5.0で100%信頼度
  }

  /// 直近N個のステップ間隔（ミリ秒）を取得するメソッド
  List<double> getLatestStepIntervals({int count = 5}) {
    // 最近の周波数から間隔を計算
    List<double> intervals = [];
    for (double freq in _recentFrequencies) {
      if (freq > 0) {
        // 周波数から間隔（ミリ秒）に変換
        double intervalMs = 1000.0 / freq;
        intervals.add(intervalMs);
      }
    }

    // 必要な数だけ返す
    if (intervals.isEmpty) return [];
    int numIntervals = math.min(count, intervals.length);
    return intervals.sublist(intervals.length - numIntervals);
  }

  /// 内部状態をリセット
  void reset() {
    _dataBuffer.clear();
    _currentSpm = 0.0;
    _reliability = 0.0;
    _stepCount = 0;
    _lastProcessingTime = 0;
    _recentFrequencies.clear();
    _fftMagnitudes.clear();
    print("GaitAnalysisService reset.");
  }
}

/// 複素数クラス（FFT計算用）
class _Complex {
  final double real;
  final double imag;

  _Complex(this.real, this.imag);

  // 複素数の加算
  _Complex operator +(_Complex other) {
    return _Complex(real + other.real, imag + other.imag);
  }

  // 複素数の減算
  _Complex operator -(_Complex other) {
    return _Complex(real - other.real, imag - other.imag);
  }

  // 複素数の乗算
  _Complex operator *(_Complex other) {
    return _Complex(real * other.real - imag * other.imag,
        real * other.imag + imag * other.real);
  }

  // 絶対値（大きさ）の計算
  double get magnitude => math.sqrt(real * real + imag * imag);

  @override
  String toString() => '($real, ${imag}i)';
}

/// 周波数ピーク情報を保持するクラス
class _FrequencyPeak {
  final double frequency; // 周波数(Hz)
  final double amplitude; // 振幅値
  final double snr; // 信号対ノイズ比

  _FrequencyPeak(this.frequency, this.amplitude, this.snr);

  @override
  String toString() =>
      'Peak(${frequency.toStringAsFixed(2)}Hz, amp=${amplitude.toStringAsFixed(2)}, SNR=${snr.toStringAsFixed(2)})';
}
