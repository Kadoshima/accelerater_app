import 'dart:collection';
import 'dart:math' as math;
import '../models/sensor_data.dart';

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
/// アルゴリズム仕様に基づき、合成加速度 + ローパスフィルタ + 動的閾値 + スライドウィンドウを使用
class GaitAnalysisService {
  // --- 設定パラメータ ---
  final double samplingRate; // Hz (例: 50.0)
  final double lowPassCutoffFreq; // ローパスフィルタカットオフ周波数 (Hz)
  final double minStepIntervalSec; // 最小ステップ間隔 (秒)
  final double maxStepIntervalSec; // 最大ステップ間隔 (秒)
  final double minDynamicThreshold; // 動的閾値の下限 (G)
  final double thresholdFactor; // 動的閾値計算係数 (例: 0.6 = 前回のピークの60%)
  final double windowSizeSec; // SPM計算用ウィンドウサイズ (秒)
  final double slideSizeSec; // ウィンドウスライド幅 (秒)
  final double minSpm; // SPMの下限
  final double maxSpm; // SPMの上限
  final int historyBufferSize; // フィルタ/ピーク検出に必要なバッファサイズ
  final double minPeakValleyDiff; // ピークと谷の最小差（ノイズ対策）
  final double minValleyToPeakDiff; // 谷から次のピークまでの最小上昇量

  // --- 内部状態変数 ---
  final Queue<M5SensorData> _sensorHistory; // 最近のセンサーデータ履歴
  final Queue<double> _filteredMagnitudeBuffer; // フィルタリング後の合成加速度バッファ
  final List<_StepEvent> _stepEvents; // すべてのステップイベント履歴
  double _previousFilteredMagnitude = 1.0; // ローパスフィルタの内部状態 (初期値 1G)
  final double _filterAlpha; // ローパスフィルタ係数

  double _lastPeakMagnitude = 1.2; // 最後に検出されたピークの振幅 (初期値: 静止+α)
  double _dynamicThreshold; // 現在の動的閾値
  bool _isPotentialPeak = false; // ピーク候補フラグ
  double _valleyAfterPeak = double.maxFinite; // ピーク後の谷の深さ
  int _lastStepTimestamp = 0; // 最後のステップのタイムスタンプ
  double _lastValleyValue = 1.0; // 最後に検出された谷の値
  int _lastWindowUpdateTime = 0; // 最後にウィンドウ計算した時刻

  // --- 結果 ---
  int _stepCount = 0;
  double _currentSpm = 0.0;
  double _reliability = 0.0; // 検出の信頼度

  // デバッグ用カウンター
  int _sampleCount = 0;

  // --- ゲッター ---
  int get stepCount => _stepCount;
  double get currentSpm => _currentSpm;
  double get lastPeakMagnitude => _lastPeakMagnitude;
  double get dynamicThreshold => _dynamicThreshold;
  double get reliability => _reliability;

  /// 直近N個のステップ間隔（ミリ秒）を取得するメソッド
  List<double> getLatestStepIntervals({int count = 5}) {
    List<double> intervals = [];
    if (_stepEvents.length >= 2) {
      // 使用する間隔の数を計算（最大count個、ただし少なくとも1つのステップイベント間隔が必要）
      int numIntervals = math.min(count, _stepEvents.length - 1);

      // 最新のステップから順に間隔を計算
      for (int i = _stepEvents.length - 1;
          i >= _stepEvents.length - numIntervals;
          i--) {
        // 現在のステップと一つ前のステップの間隔を計算
        double interval =
            (_stepEvents[i].timestamp - _stepEvents[i - 1].timestamp)
                .toDouble();

        // 妥当な間隔のみ追加（非常に長い間隔や短すぎる間隔を除外）
        if (interval >= minStepIntervalSec * 1000 &&
            interval <= maxStepIntervalSec * 1000) {
          intervals.insert(0, interval); // 古い順に追加
        }
      }
    }
    return intervals;
  }

  /// コンストラクタ
  GaitAnalysisService({
    this.samplingRate = 50.0,
    this.lowPassCutoffFreq = 1.5, // 1.5Hzカットオフ（以前は2.5Hz, 5Hz）
    this.minStepIntervalSec = 0.3, // 300ms (200 SPM)
    this.maxStepIntervalSec = 1.5, // 1500ms (40 SPM)
    this.minDynamicThreshold =
        0.18, // 閾値の下限 0.18G（静止状態の1Gより低い値）- 以前は0.25G, 0.3G, 0.45G
    this.thresholdFactor = 0.25, // ピークの25%を閾値に - 以前は0.35, 0.4, 0.5
    this.windowSizeSec = 10.0, // 10秒ウィンドウ - 以前は20秒
    this.slideSizeSec = 1.0, // 1秒スライド - 以前は2秒
    this.minSpm = 40.0,
    this.maxSpm = 200.0,
    this.historyBufferSize = 5, // フィルタ/ピーク検出に最低5サンプル使用
    this.minPeakValleyDiff = 0.05, // ピークと谷の差が0.05G以上必要 - 以前は0.08G, 0.1G, 0.15G
    this.minValleyToPeakDiff =
        0.03, // 谷から次のピークまでの上昇量が0.03G以上必要 - 以前は0.05G, 0.08G, 0.12G
  })  : _filterAlpha = _calculateFilterAlpha(samplingRate, lowPassCutoffFreq),
        _dynamicThreshold = minDynamicThreshold, // 初期閾値は下限値に設定
        _sensorHistory = Queue<M5SensorData>(),
        _filteredMagnitudeBuffer = Queue<double>(),
        _stepEvents = [] {
    print('GaitAnalysisService初期化(スライドウィンドウ方式): '
        'フィルタα=${_filterAlpha.toStringAsFixed(3)}, '
        '閾値=${minDynamicThreshold}G, '
        'ウィンドウ=${windowSizeSec}秒, '
        'スライド=${slideSizeSec}秒');
  }

  /// フィルタ係数アルファを計算
  static double _calculateFilterAlpha(double samplingRate, double cutoffFreq) {
    double dt = 1.0 / samplingRate;
    double rc = 1.0 / (2.0 * math.pi * cutoffFreq);
    return dt / (rc + dt);
  }

  /// 新しいセンサーデータを処理
  void addSensorData(M5SensorData sensorData) {
    _sampleCount++;

    // 1. データバッファリング
    _sensorHistory.add(sensorData);
    // 必要最低限のサイズを保持
    while (_sensorHistory.length > historyBufferSize + 5) {
      // 少し余裕を持たせる
      _sensorHistory.removeFirst();
    }

    // 2. 合成加速度を計算し、ローパスフィルタ適用
    double magnitude = sensorData.magnitude ?? 1.0; // magnitudeがnullなら1Gとする
    double currentFilteredMagnitude = _applyLowPassFilter(magnitude);
    _filteredMagnitudeBuffer.add(currentFilteredMagnitude);
    while (_filteredMagnitudeBuffer.length > historyBufferSize + 5) {
      _filteredMagnitudeBuffer.removeFirst();
    }

    // 100サンプルごとにデバッグ情報表示
    if (_sampleCount % 100 == 0) {
      print(
          'GaitAnalysis状態: サンプル数=$_sampleCount, 現在閾値=${_dynamicThreshold.toStringAsFixed(3)}G, '
          'SPM=$_currentSpm, ステップ数=$_stepCount, ステップ履歴=${_stepEvents.length}件');
      print('最新データ: 生=$magnitude, フィルタ後=$currentFilteredMagnitude');
    }

    // 3. ステップ検出を実行 (フィルタ後の値とタイムスタンプを使用)
    _detectStep(currentFilteredMagnitude, sensorData.timestamp);

    // 4. スライドウィンドウ方式でSPMを計算（slideSizeSec秒ごとに実行）
    int currentTime = sensorData.timestamp;
    if (_lastWindowUpdateTime == 0 ||
        (currentTime - _lastWindowUpdateTime) >= (slideSizeSec * 1000)) {
      _calculateSpmWithWindow(currentTime);
      _lastWindowUpdateTime = currentTime;
    }

    // 5. 古いステップイベントを削除（現在時刻からwindowSizeSec*2秒以上前のもの）
    _cleanupOldStepEvents(sensorData.timestamp);
  }

  /// 古いステップイベントの削除
  void _cleanupOldStepEvents(int currentTimestamp) {
    if (_stepEvents.isEmpty) return;

    // 現在時刻からwindowSizeSec*2秒より古いイベントを削除
    int threshold = currentTimestamp - (windowSizeSec.toInt() * 2 * 1000);
    while (_stepEvents.isNotEmpty && _stepEvents.first.timestamp < threshold) {
      _stepEvents.removeAt(0);
    }
  }

  /// ローパスフィルタを適用 (1次IIR)
  double _applyLowPassFilter(double newValue) {
    // 初期値(静止状態の1Gなど)を適切に設定することが重要
    _previousFilteredMagnitude = _filterAlpha * newValue +
        (1.0 - _filterAlpha) * _previousFilteredMagnitude;
    return _previousFilteredMagnitude;
  }

  /// ステップ検出ロジック
  void _detectStep(double currentFilteredMag, int timestamp) {
    // 十分なデータがない場合はスキップ
    if (_filteredMagnitudeBuffer.length < 3) {
      return;
    }

    // ピーク検出のための値を取得 (最新から2番目を中心に比較)
    double prevFilteredMag =
        _filteredMagnitudeBuffer.elementAt(_filteredMagnitudeBuffer.length - 2);
    double prevPrevFilteredMag =
        _filteredMagnitudeBuffer.elementAt(_filteredMagnitudeBuffer.length - 3);

    // 動的閾値を計算 (下限値を保証)
    // 閾値は、前回のピークの振幅に基づいて決定するが、最低でもminDynamicThresholdは確保する
    _dynamicThreshold =
        math.max(minDynamicThreshold, _lastPeakMagnitude * thresholdFactor);

    // --- ピーク候補の検出 ---
    // 条件: 閾値を超え、かつ上昇から下降に転じた点 (prevがピーク)
    if (!_isPotentialPeak) {
      // まだピーク候補がない場合、新しいピークを探す
      // ピーク検出条件をデバッグ表示
      if (_sampleCount % 50 == 0) {
        print('ピーク検出チェック: '
            'prev=${prevFilteredMag.toStringAsFixed(3)}G, '
            '閾値=${_dynamicThreshold.toStringAsFixed(3)}G, '
            'prevPrev=${prevPrevFilteredMag.toStringAsFixed(3)}G, '
            'current=${currentFilteredMag.toStringAsFixed(3)}G');
      }

      if (prevFilteredMag > _dynamicThreshold &&
          prevFilteredMag > prevPrevFilteredMag &&
          prevFilteredMag > currentFilteredMag) {
        // 新しいピーク候補を検出
        _isPotentialPeak = true;
        // ピーク値を保存（後で使用）
        _lastPeakMagnitude = prevFilteredMag;
        _valleyAfterPeak = currentFilteredMag; // ピーク直後の値を谷の初期値とする

        print(
            'Potential peak detected: ${_lastPeakMagnitude.toStringAsFixed(3)} > '
            'Thr: ${_dynamicThreshold.toStringAsFixed(3)} @ $timestamp');
      }
    } else {
      // すでにピーク候補がある場合、谷を探す
      if (currentFilteredMag < prevFilteredMag) {
        // まだ下降中、谷の値を更新
        _valleyAfterPeak = math.min(_valleyAfterPeak, currentFilteredMag);
      } else if (currentFilteredMag > prevFilteredMag) {
        // 上昇に転じた、谷が確定した
        // ピークと谷の差が十分かチェック
        double peakValleyDiff = _lastPeakMagnitude - _valleyAfterPeak;
        double valleyToPeakDiff = currentFilteredMag - _valleyAfterPeak;

        print('Step check: Peak=${_lastPeakMagnitude.toStringAsFixed(3)}, '
            'Valley=${_valleyAfterPeak.toStringAsFixed(3)}, '
            'Diff=${peakValleyDiff.toStringAsFixed(3)}, '
            'ValleyToCurrent=${valleyToPeakDiff.toStringAsFixed(3)}');

        // 振幅チェック - 条件を緩和
        if (peakValleyDiff < minPeakValleyDiff ||
            valleyToPeakDiff < minValleyToPeakDiff) {
          print(
              'Step rejected (small amplitude: peak-valley=${peakValleyDiff.toStringAsFixed(3)}, '
              'valley-current=${valleyToPeakDiff.toStringAsFixed(3)})');
          _isPotentialPeak = false; // フラグリセット
          _valleyAfterPeak = double.maxFinite;
          return; // ステップとしない
        }

        // ステップ間隔をチェック
        double intervalSeconds = (_lastStepTimestamp > 0)
            ? (timestamp - _lastStepTimestamp) / 1000.0
            : double.maxFinite; // 最初のステップは間隔無限大

        // 最小間隔チェック
        if (intervalSeconds >= minStepIntervalSec) {
          // 長すぎる間隔の場合、新しい歩行シーケンスとして扱う（ログ表示のみ）
          if (intervalSeconds > maxStepIntervalSec) {
            print(
                'New sequence likely started (interval: ${intervalSeconds.toStringAsFixed(2)}s > '
                '${maxStepIntervalSec}s)');
          }

          // ステップ確定！
          _stepCount++;
          _lastStepTimestamp = timestamp;
          _lastValleyValue = _valleyAfterPeak; // 最後の谷の値を保存

          // 信頼度計算 (ピークと谷の差が大きいほど信頼度が高い)
          _reliability = math.min(1.0, peakValleyDiff / 1.0);

          // ステップイベントをリストに追加
          _stepEvents.add(_StepEvent(
              timestamp, _lastPeakMagnitude, _valleyAfterPeak, _reliability));

          print(
              'Step confirmed! Count: $_stepCount, Interval: ${intervalSeconds.toStringAsFixed(2)}s, '
              'Peak: ${_lastPeakMagnitude.toStringAsFixed(3)}, Valley: ${_valleyAfterPeak.toStringAsFixed(3)}, '
              'Reliability: ${(_reliability * 100).toStringAsFixed(1)}%');

          // SPMをすぐに更新
          _calculateSpmWithWindow(timestamp);
        } else {
          print(
              'Step rejected (too short interval: ${intervalSeconds.toStringAsFixed(2)}s < '
              '${minStepIntervalSec}s)');
        }

        // ステップ判定処理が終わったらフラグと谷をリセット
        _isPotentialPeak = false;
        _valleyAfterPeak = double.maxFinite;
      }
    }
  }

  /// スライドウィンドウ方式での歩行ピッチ(SPM)計算
  void _calculateSpmWithWindow(int currentTimestamp) {
    // ウィンドウサイズ内のステップイベント数をカウント
    int windowStartTime = currentTimestamp - (windowSizeSec * 1000).toInt();

    // 現在のウィンドウ内のステップイベントを抽出
    List<_StepEvent> windowEvents = _stepEvents
        .where((event) => event.timestamp >= windowStartTime)
        .toList();

    if (windowEvents.isEmpty) {
      // ウィンドウ内にステップがない場合はSPMをゼロに
      _currentSpm = 0.0;
      _reliability = 0.0;
      print('Window empty - SPM set to 0');
      return;
    }

    // 直接ウィンドウ内のステップ数をカウントし、SPMを計算
    int stepCount = windowEvents.length;
    double windowSizeMinutes = windowSizeSec / 60.0;

    // SPMを計算： ステップ数 ÷ ウィンドウサイズ（分）
    _currentSpm = (stepCount / windowSizeMinutes).clamp(minSpm, maxSpm);

    // 信頼度は最新のステップの信頼度を使用
    _reliability = windowEvents.last.reliability;

    print(
        'SPM updated: ${_currentSpm.toStringAsFixed(1)} (window size: ${windowSizeSec}s, '
        'steps in window: $stepCount, effective SPM: ${(stepCount / windowSizeMinutes).toStringAsFixed(1)})');
  }

  /// 長時間ステップがない場合にSPMをリセットするヘルパー関数
  void _resetSpmIfInactive() {
    if (_lastStepTimestamp > 0) {
      double timeSinceLastStepSec =
          (DateTime.now().millisecondsSinceEpoch - _lastStepTimestamp) / 1000.0;
      // 最大ステップ間隔の1.5倍の時間、ステップがなければ停止とみなす
      if (timeSinceLastStepSec > maxStepIntervalSec * 1.5) {
        if (_currentSpm != 0.0) {
          print(
              'Resetting SPM to 0 due to inactivity ($timeSinceLastStepSec sec)');
          _currentSpm = 0.0;
        }
      }
    } else if (_stepEvents.isEmpty && _currentSpm != 0.0) {
      // ステップイベントがまだないのにSPMが0でない場合はリセット
      _currentSpm = 0.0;
    }
  }

  /// 内部状態をリセット
  void reset() {
    _sensorHistory.clear();
    _filteredMagnitudeBuffer.clear();
    _previousFilteredMagnitude = 1.0; // フィルタ状態リセット
    _stepEvents.clear();
    _lastPeakMagnitude = 1.2; // ピーク振幅リセット
    _dynamicThreshold = minDynamicThreshold; // 閾値リセット
    _isPotentialPeak = false;
    _valleyAfterPeak = double.maxFinite;
    _lastStepTimestamp = 0;
    _lastWindowUpdateTime = 0;
    _stepCount = 0;
    _currentSpm = 0.0;
    _reliability = 0.0;
    _sampleCount = 0;
    print("GaitAnalysisService reset.");
  }
}
