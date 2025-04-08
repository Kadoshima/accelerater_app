import 'dart:collection';
import 'dart:math' as math;
import 'package:collection/collection.dart'; // for List.sum, average

/// 足首センサーデータから歩行ステップとピッチ(SPM)を検出するサービス
class GaitAnalysisService {
  // --- 設定パラメータ ---
  final double samplingRate; // Hz (例: 50.0)
  final int accWindowSize; // 加速度データの移動平均ウィンドウサイズ (サンプル数)
  final int gyroWindowSize; // ジャイロデータの移動平均ウィンドウサイズ (サンプル数)
  final int thresholdWindowSize; // 動的閾値計算用のウィンドウサイズ (サンプル数)
  final double minStepIntervalSec; // 最小ステップ間隔 (秒)
  final double maxStepIntervalSec; // 最大ステップ間隔 (秒)
  final double dynamicThresholdFactor; // 動的閾値の感度係数 (標準偏差に対する倍率)
  final double peakSimilarityThreshold; // 加速度とジャイロのピーク同時性閾値 (秒)
  final int spmCalculationWindow; // SPM計算に使うステップ数

  // --- 内部状態変数 ---
  final Queue<double> _accMagBuffer; // 合成加速度バッファ
  final Queue<double> _gyroXBuffer; // ジャイロX軸バッファ (例としてX軸を使用)
  final Queue<int> _timestampBuffer; // タイムスタンプバッファ (ミリ秒)

  final Queue<double> _smoothedAccMagBuffer; // 平滑化された加速度バッファ
  final Queue<double> _smoothedGyroXBuffer; // 平滑化されたジャイロバッファ

  double _dynamicAccThreshold = 0.2; // 動的閾値 (加速度) - 初期値
  double _dynamicGyroThreshold = 50.0; // 動的閾値 (ジャイロ) - 初期値

  final List<int> _stepTimestamps = []; // 検出されたステップのタイムスタンプ (ミリ秒)
  int _lastAccPeakTimestamp = 0;
  int _lastGyroPeakTimestamp = 0;

  // --- 結果 ---
  int _stepCount = 0;
  double _currentSpm = 0.0; // Steps Per Minute

  // --- ゲッター ---
  int get stepCount => _stepCount;
  double get currentSpm => _currentSpm;

  /// コンストラクタ
  GaitAnalysisService({
    this.samplingRate = 50.0,
    int accWindowMillis = 100, // 100ms window for acc smoothing
    int gyroWindowMillis = 150, // 150ms window for gyro smoothing
    int thresholdWindowSec = 3, // 3 seconds window for dynamic threshold
    this.minStepIntervalSec = 0.3, // 300ms (200 SPM)
    this.maxStepIntervalSec = 1.5, // 1500ms (40 SPM)
    this.dynamicThresholdFactor = 0.8, // stddev * 0.8
    this.peakSimilarityThreshold = 0.1, // 100ms
    this.spmCalculationWindow = 5, // Use last 5 steps for SPM
  })  : accWindowSize = (samplingRate * accWindowMillis / 1000.0).round(),
        gyroWindowSize = (samplingRate * gyroWindowMillis / 1000.0).round(),
        thresholdWindowSize = (samplingRate * thresholdWindowSec).round(),
        _accMagBuffer = Queue<double>(),
        _gyroXBuffer = Queue<double>(),
        _timestampBuffer = Queue<int>(),
        _smoothedAccMagBuffer = Queue<double>(),
        _smoothedGyroXBuffer = Queue<double>();

  /// 新しいセンサーデータを処理
  void addSensorData(dynamic sensorDataObject) {
    // 1. データ抽出とバッファリング
    double? accX = sensorDataObject.accX;
    double? accY = sensorDataObject.accY;
    double? accZ = sensorDataObject.accZ;
    double? gyroX = sensorDataObject.gyroX; // 仮にX軸を使用
    int timestamp =
        sensorDataObject.timestamp ?? DateTime.now().millisecondsSinceEpoch;

    if (accX == null || accY == null || accZ == null || gyroX == null) {
      // 必要なデータが欠けている場合はスキップ
      return;
    }

    // 合成加速度計算
    double accMag = math.sqrt(accX * accX + accY * accY + accZ * accZ);

    _accMagBuffer.add(accMag);
    _gyroXBuffer.add(gyroX);
    _timestampBuffer.add(timestamp);

    // バッファサイズ維持 (閾値計算用)
    while (_accMagBuffer.length > thresholdWindowSize) {
      _accMagBuffer.removeFirst();
    }
    while (_gyroXBuffer.length > thresholdWindowSize) {
      _gyroXBuffer.removeFirst();
    }
    while (_timestampBuffer.length > thresholdWindowSize) {
      _timestampBuffer.removeFirst();
    }

    // 2. 信号の平滑化 (移動平均)
    _smoothedAccMagBuffer
        .add(_calculateMovingAverage(_accMagBuffer.toList(), accWindowSize));
    while (_smoothedAccMagBuffer.length > accWindowSize + 5) {
      // 少し余裕を持たせる
      _smoothedAccMagBuffer.removeFirst();
    }

    _smoothedGyroXBuffer
        .add(_calculateMovingAverage(_gyroXBuffer.toList(), gyroWindowSize));
    while (_smoothedGyroXBuffer.length > gyroWindowSize + 5) {
      _smoothedGyroXBuffer.removeFirst();
    }

    // 平滑化データが十分溜まるまで待つ
    if (_smoothedAccMagBuffer.length < 3 || _smoothedGyroXBuffer.length < 3) {
      return;
    }

    // 3. 動的閾値の更新
    _updateDynamicThresholds();

    // 4. ピーク検出
    _detectPeaks(timestamp);

    // 5. 歩行ピッチ(SPM)の計算
    _calculateSpm();
  }

  /// 移動平均を計算
  double _calculateMovingAverage(List<double> data, int windowSize) {
    if (data.isEmpty) return 0.0;
    int actualWindowSize = math.min(data.length, windowSize);
    if (actualWindowSize <= 0) return data.last; // windowSize=0の場合など

    double sum = 0;
    // リストの末尾から指定サイズ分の合計を計算
    for (int i = data.length - 1; i >= data.length - actualWindowSize; i--) {
      sum += data[i];
    }
    return sum / actualWindowSize;
  }

  /// 動的閾値を更新
  void _updateDynamicThresholds() {
    if (_accMagBuffer.length < thresholdWindowSize * 0.5)
      return; // 十分なデータがない場合は更新しない

    // 加速度の閾値
    double accMean = _accMagBuffer.average;
    double accStdDev = _calculateStdDev(_accMagBuffer.toList(), accMean);
    // 閾値は標準偏差に基づく。ある程度の最小値も保証する。
    _dynamicAccThreshold =
        math.max(0.1, accStdDev * dynamicThresholdFactor); // 最小0.1G程度の変動は見る

    // ジャイロの閾値 (絶対値で計算)
    List<double> absGyroX = _gyroXBuffer.map((g) => g.abs()).toList();
    double gyroMean = absGyroX.average;
    double gyroStdDev = _calculateStdDev(absGyroX, gyroMean);
    _dynamicGyroThreshold = math.max(
        30.0, gyroStdDev * dynamicThresholdFactor); // 最小30 deg/s 程度の変動は見る
  }

  /// 標準偏差を計算
  double _calculateStdDev(List<double> data, double mean) {
    if (data.length < 2) return 0.0;
    double variance = data.map((x) => math.pow(x - mean, 2)).toList().average;
    return math.sqrt(variance);
  }

  /// ピーク検出
  void _detectPeaks(int currentTimestamp) {
    // --- 加速度ピーク検出 ---
    bool isAccPeak =
        _isPeak(_smoothedAccMagBuffer.toList(), _dynamicAccThreshold);
    if (isAccPeak) {
      _lastAccPeakTimestamp = currentTimestamp;
      // デバッグ用: print('Acc Peak detected at $currentTimestamp');
    }

    // --- ジャイロピーク検出 ---
    // ジャイロは正負両方のピークを見る可能性があるため絶対値で平滑化・検出
    // または、特定の回転方向のみをターゲットにする（ここでは例として絶対値）
    bool isGyroPeak = _isPeak(_smoothedGyroXBuffer.map((g) => g.abs()).toList(),
        _dynamicGyroThreshold);
    if (isGyroPeak) {
      _lastGyroPeakTimestamp = currentTimestamp;
      // デバッグ用: print('Gyro Peak detected at $currentTimestamp');
    }

    // --- ステップ判定 ---
    // 加速度ピークがあり、かつ直近(閾値内)にジャイロピークもあるか？
    if (isAccPeak &&
        (_lastGyroPeakTimestamp - currentTimestamp).abs() <=
            peakSimilarityThreshold * 1000) {
      // さらに、前回のステップからの間隔が短すぎないか？
      if (_stepTimestamps.isEmpty ||
          (currentTimestamp - _stepTimestamps.last) >=
              minStepIntervalSec * 1000) {
        // ステップ確定
        _stepTimestamps.add(currentTimestamp);
        _stepCount++;
        // デバッグ用: print('Step confirmed at $currentTimestamp! Count: $_stepCount');

        // 古いタイムスタンプを削除（例: SPM計算ウィンドウの2倍保持）
        while (_stepTimestamps.length > spmCalculationWindow * 2) {
          _stepTimestamps.removeAt(0);
        }
      } else {
        // デバッグ用: print('Step rejected (too close) at $currentTimestamp');
      }
    }
  }

  /// リストの最新の値がピークかどうかを判定 (簡易版)
  /// リストの中央の値と比較する改善も可能
  bool _isPeak(List<double> bufferList, double threshold) {
    // QueueをListに変換せずに直接アクセスするように変更検討
    if (bufferList.length < 3) return false;
    double currentValue = bufferList.last;
    double prevValue = bufferList.elementAt(bufferList.length - 2);
    // double prevPrevValue = bufferList.elementAt(bufferList.length - 3);

    // 閾値を超え、かつ直前の値より大きく、さらにその前の値よりも上昇しているか（より明確なピーク）
    // bool basicPeak = currentValue > prevValue && prevValue > prevPrevValue && currentValue > threshold;

    // よりロバストなピーク検出: ウィンドウの中央付近(最新の値)が左右の値より大きいか
    int checkIndex = bufferList.length - 2; // 最新から2番目（最新値はまだ上昇中かもしれないため）
    if (checkIndex < 1) return false; // 十分なデータがない

    double centerValue = bufferList[checkIndex];
    double leftValue = bufferList[checkIndex - 1];
    double rightValue = bufferList[checkIndex + 1]; // 最新の値

    bool isPeakCondition = centerValue > leftValue &&
        centerValue > rightValue &&
        centerValue > threshold;

    return isPeakCondition;
  }

  /// 歩行ピッチ(SPM)を計算
  void _calculateSpm() {
    if (_stepTimestamps.length < 2) {
      _currentSpm = 0.0;
      return;
    }

    // 計算に使う最新のステップ数
    int stepsToUse = math.min(spmCalculationWindow, _stepTimestamps.length - 1);
    if (stepsToUse < 1) {
      _currentSpm = 0.0;
      return;
    }

    // 直近Nステップの間隔をリストアップ
    List<int> intervals = [];
    for (int i = _stepTimestamps.length - 1;
        i >= _stepTimestamps.length - stepsToUse;
        i--) {
      int interval = _stepTimestamps[i] - _stepTimestamps[i - 1];
      // 妥当な範囲の間隔のみを使用
      if (interval >= minStepIntervalSec * 1000 &&
          interval <= maxStepIntervalSec * 1000) {
        intervals.add(interval);
      }
    }

    if (intervals.isEmpty) {
      _currentSpm = 0.0; // 有効な間隔がない場合は0
      return;
    }

    // 平均間隔を計算 (ミリ秒)
    double averageIntervalMillis = intervals.average;

    // SPMに変換
    _currentSpm = 60000.0 / averageIntervalMillis;

    // 不自然な値のクリッピング (例: 40-200 SPM)
    _currentSpm = _currentSpm.clamp(40.0, 200.0);
  }

  /// 内部状態をリセット
  void reset() {
    _accMagBuffer.clear();
    _gyroXBuffer.clear();
    _timestampBuffer.clear();
    _smoothedAccMagBuffer.clear();
    _smoothedGyroXBuffer.clear();
    _stepTimestamps.clear();
    _lastAccPeakTimestamp = 0;
    _lastGyroPeakTimestamp = 0;
    _stepCount = 0;
    _currentSpm = 0.0;
    // 閾値は初期値に戻すか、保持するかは設計による
    _dynamicAccThreshold = 0.2;
    _dynamicGyroThreshold = 50.0;
    print("GaitAnalysisService reset.");
  }
}
