import 'dart:collection';
import 'dart:math' as math;
import '../models/sensor_data.dart';
import 'dart:typed_data';

/// 内部データクラス: ステップイベント
class _StepEvent {
  final int timestamp; // ミリ秒
  final double peakValue;
  final double valleyValue;
  final double reliability;

  _StepEvent(
      this.timestamp, this.peakValue, this.valleyValue, this.reliability);
}

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
    this.totalDataSeconds = 15, // 15秒分のデータを保持
    this.windowSizeSeconds = 3, // 3秒のウィンドウでFFT計算
    this.slideIntervalSeconds = 1, // 1秒ごとにスライド
    this.minFrequency = 0.6, // 最小周波数 0.6Hz (36 SPM)
    this.maxFrequency = 3.0, // 最大周波数 3.0Hz (180 SPM)
    this.minSpm = 40.0, // 最小SPM (40 = 非常にゆっくりした歩行)
    this.maxSpm = 180.0, // 最大SPM (180 = 非常に速い走り)
    this.smoothingFactor = 0.3, // 新しい値の30%を反映
  }) : _dataBuffer = Queue<M5SensorData>() {
    print('GaitAnalysisService初期化(FFT方式): '
        'バッファ=${totalDataSeconds}秒, '
        'ウィンドウ=${windowSizeSeconds}秒, '
        'スライド=${slideIntervalSeconds}秒, '
        'サンプリングレート=60Hz固定, '
        '周波数範囲=${minFrequency}Hz-${maxFrequency}Hz');
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
      print(
          '実際のサンプリングレート: ${estimatedRate}Hz (データ数: ${_dataBuffer.length}, 期間: ${durationSeconds.toStringAsFixed(2)}秒)');
      print('固定サンプリングレート60Hzを使用中');
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

    // マグニチュード値を取得
    for (var data in recentData) {
      windowData.add(data.magnitude ?? 0.0);
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

      // 信頼度の計算（最大値と全体の比率から）
      _reliability = _calculateReliability(magnitudes, peakFrequency);

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

  /// 周波数ピークの検出
  double _findPeakFrequency(List<double> magnitudes) {
    int n = magnitudes.length;
    int peakIndex = -1;
    double peakValue = 0.0;

    // 歩行周波数範囲内のピークを探す
    int minBin = (minFrequency * windowSizeSeconds).round();
    int maxBin = (maxFrequency * windowSizeSeconds).round();

    // 範囲の調整
    minBin = math.max(1, minBin); // 0より大きい（DCは除外）
    maxBin = math.min(n - 1, maxBin); // 配列範囲内

    // ピーク候補の検出
    for (int i = minBin; i <= maxBin; i++) {
      if (magnitudes[i] > peakValue) {
        peakValue = magnitudes[i];
        peakIndex = i;
      }
    }

    if (peakIndex > 0) {
      // バイン番号から周波数への変換 (f = bin * fs / N)
      double frequency = peakIndex / (windowSizeSeconds.toDouble());
      return frequency;
    }

    return 0.0; // ピークなし
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
