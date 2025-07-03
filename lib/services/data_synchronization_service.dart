import 'dart:async';
import 'dart:collection';
import '../models/nback_models.dart';
import 'extended_data_recorder.dart';
import 'phase_error_engine.dart';

// 一時的なプレースホルダークラス
class IMUData {
  final DateTime timestamp;
  final double ax, ay, az;
  final double gx, gy, gz;
  
  IMUData({
    required this.timestamp,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });
}

class HeartRateData {
  final DateTime timestamp;
  final int bpm;
  final double confidence;
  
  HeartRateData({
    required this.timestamp,
    required this.bpm,
    required this.confidence,
  });
}

/// データ同期サービス
/// 異なるサンプリングレートのデータを同期・管理
class DataSynchronizationService {
  // データレコーダー
  final ExtendedDataRecorder _dataRecorder;
  final PhaseErrorEngine _phaseErrorEngine;
  
  // サンプリングレート
  static const int imuSamplingRate = 100; // Hz
  static const int heartRateSamplingInterval = 3000; // ms (3秒)
  
  // データバッファ
  final Queue<SynchronizedDataPoint> _dataBuffer = Queue<SynchronizedDataPoint>();
  static const int maxBufferSize = 1000; // 10秒分のデータ
  
  // タイムスタンプ同期
  DateTime? _sessionStartTime;
  final Map<String, DateTime> _lastDataTimestamp = {};
  
  // ストリーム
  final _syncDataController = StreamController<SynchronizedDataPoint>.broadcast();
  Stream<SynchronizedDataPoint> get syncDataStream => _syncDataController.stream;
  
  // 統計情報
  final Map<String, int> _dataCounters = {};
  final Map<String, double> _dataSyncErrors = {};
  
  DataSynchronizationService({
    required ExtendedDataRecorder dataRecorder,
    required PhaseErrorEngine phaseErrorEngine,
  }) : _dataRecorder = dataRecorder,
       _phaseErrorEngine = phaseErrorEngine;
  
  /// セッションを開始
  void startSession(String sessionId) {
    _sessionStartTime = DateTime.now();
    _dataBuffer.clear();
    _lastDataTimestamp.clear();
    _dataCounters.clear();
    _dataSyncErrors.clear();
  }
  
  /// IMUデータを記録
  void recordIMUData({
    required String sensorId,
    required IMUData data,
  }) {
    if (_sessionStartTime == null) return;
    
    final syncPoint = SynchronizedDataPoint(
      timestamp: data.timestamp,
      relativeTime: _getRelativeTime(data.timestamp),
      dataType: DataType.imu,
      sensorId: sensorId,
      imuData: data,
    );
    
    _addToBuffer(syncPoint);
    _updateTimestamp('imu_$sensorId', data.timestamp);
    _incrementCounter('imu_$sensorId');
  }
  
  /// 心拍データを記録
  void recordHeartRateData({
    required HeartRateData data,
  }) {
    if (_sessionStartTime == null) return;
    
    final syncPoint = SynchronizedDataPoint(
      timestamp: data.timestamp,
      relativeTime: _getRelativeTime(data.timestamp),
      dataType: DataType.heartRate,
      sensorId: 'polar_h10',
      heartRateData: data,
    );
    
    _addToBuffer(syncPoint);
    _updateTimestamp('heart_rate', data.timestamp);
    _incrementCounter('heart_rate');
    
    // Polar H10の3秒更新に対応した同期エラー計算
    _calculateHeartRateSyncError(data.timestamp);
  }
  
  /// N-back応答を記録
  void recordNBackResponse({
    required NBackResponse response,
    required String sessionId,
  }) {
    if (_sessionStartTime == null) return;
    
    final syncPoint = SynchronizedDataPoint(
      timestamp: response.timestamp,
      relativeTime: _getRelativeTime(response.timestamp),
      dataType: DataType.nbackResponse,
      sensorId: sessionId,
      nbackResponse: response,
    );
    
    _addToBuffer(syncPoint);
    _updateTimestamp('nback', response.timestamp);
    _incrementCounter('nback_responses');
    
    // 拡張データレコーダーにイベントを記録
    _dataRecorder.recordEvent(
      eventType: 'nback_response',
      data: {
        'sequenceIndex': response.sequenceIndex,
        'presentedDigit': response.presentedDigit,
        'respondedDigit': response.respondedDigit,
        'isCorrect': response.isCorrect,
        'reactionTimeMs': response.reactionTimeMs,
        'responseType': response.responseType.name,
      },
    );
  }
  
  /// 位相誤差を記録
  void recordPhaseError({
    required DateTime clickTime,
    required DateTime heelStrikeTime,
    required double currentSpm,
  }) {
    if (_sessionStartTime == null) return;
    
    // PhaseErrorEngineに記録
    _phaseErrorEngine.recordPhaseError(
      clickTime: clickTime,
      heelStrikeTime: heelStrikeTime,
      currentSpm: currentSpm,
    );
    
    // 拡張データレコーダーにも記録
    _dataRecorder.recordPhaseError(
      clickTime: clickTime,
      heelStrikeTime: heelStrikeTime,
      currentSpm: currentSpm,
    );
    
    _incrementCounter('phase_errors');
  }
  
  /// バッファにデータを追加
  void _addToBuffer(SynchronizedDataPoint point) {
    _dataBuffer.add(point);
    
    // バッファサイズ制限
    while (_dataBuffer.length > maxBufferSize) {
      _dataBuffer.removeFirst();
    }
    
    // ストリームに送信
    _syncDataController.add(point);
  }
  
  /// 相対時間を計算
  Duration _getRelativeTime(DateTime timestamp) {
    if (_sessionStartTime == null) {
      return Duration.zero;
    }
    return timestamp.difference(_sessionStartTime!);
  }
  
  /// タイムスタンプを更新
  void _updateTimestamp(String key, DateTime timestamp) {
    _lastDataTimestamp[key] = timestamp;
  }
  
  /// カウンターを増加
  void _incrementCounter(String key) {
    _dataCounters[key] = (_dataCounters[key] ?? 0) + 1;
  }
  
  /// 心拍データの同期エラーを計算
  void _calculateHeartRateSyncError(DateTime timestamp) {
    final lastHR = _lastDataTimestamp['heart_rate'];
    if (lastHR != null) {
      final interval = timestamp.difference(lastHR).inMilliseconds;
      final expectedInterval = heartRateSamplingInterval;
      final error = (interval - expectedInterval).abs() / expectedInterval;
      _dataSyncErrors['heart_rate'] = error;
    }
  }
  
  /// 時間範囲内のデータを取得
  List<SynchronizedDataPoint> getDataInTimeRange({
    required DateTime start,
    required DateTime end,
    DataType? dataType,
  }) {
    return _dataBuffer.where((point) {
      final inRange = point.timestamp.isAfter(start) && 
                     point.timestamp.isBefore(end);
      final matchesType = dataType == null || point.dataType == dataType;
      return inRange && matchesType;
    }).toList();
  }
  
  /// 最新のデータを取得
  SynchronizedDataPoint? getLatestData(DataType dataType) {
    try {
      return _dataBuffer.lastWhere((point) => point.dataType == dataType);
    } catch (e) {
      return null;
    }
  }
  
  /// 同期統計を取得
  SynchronizationStatistics getStatistics() {
    final now = DateTime.now();
    final sessionDuration = _sessionStartTime != null 
        ? now.difference(_sessionStartTime!) 
        : Duration.zero;
    
    // データレートの計算
    final dataRates = <String, double>{};
    _dataCounters.forEach((key, count) {
      if (sessionDuration.inSeconds > 0) {
        dataRates[key] = count / sessionDuration.inSeconds;
      }
    });
    
    return SynchronizationStatistics(
      sessionDuration: sessionDuration,
      dataCounters: Map.from(_dataCounters),
      dataRates: dataRates,
      syncErrors: Map.from(_dataSyncErrors),
      bufferSize: _dataBuffer.length,
      lastTimestamps: Map.from(_lastDataTimestamp),
    );
  }
  
  /// バッファをフラッシュ
  Future<void> flushBuffer() async {
    // ExtendedDataRecorderのバッファもフラッシュ
    await _dataRecorder.stopRecording();
    _dataBuffer.clear();
  }
  
  /// リソースを解放
  void dispose() {
    _syncDataController.close();
  }
}

/// 同期されたデータポイント
class SynchronizedDataPoint {
  final DateTime timestamp;
  final Duration relativeTime;
  final DataType dataType;
  final String sensorId;
  final IMUData? imuData;
  final HeartRateData? heartRateData;
  final NBackResponse? nbackResponse;
  
  SynchronizedDataPoint({
    required this.timestamp,
    required this.relativeTime,
    required this.dataType,
    required this.sensorId,
    this.imuData,
    this.heartRateData,
    this.nbackResponse,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'relativeTimeMs': relativeTime.inMilliseconds,
      'dataType': dataType.name,
      'sensorId': sensorId,
      if (imuData != null) 'imuData': _imuDataToJson(imuData!),
      if (heartRateData != null) 'heartRateData': _heartRateDataToJson(heartRateData!),
      if (nbackResponse != null) 'nbackResponse': _nbackResponseToJson(nbackResponse!),
    };
  }
  
  Map<String, dynamic> _imuDataToJson(IMUData data) {
    return {
      'accelerometer': {
        'x': data.ax,
        'y': data.ay,
        'z': data.az,
      },
      'gyroscope': {
        'x': data.gx,
        'y': data.gy,
        'z': data.gz,
      },
    };
  }
  
  Map<String, dynamic> _heartRateDataToJson(HeartRateData data) {
    return {
      'bpm': data.bpm,
      'confidence': data.confidence,
    };
  }
  
  Map<String, dynamic> _nbackResponseToJson(NBackResponse response) {
    return {
      'sequenceIndex': response.sequenceIndex,
      'presentedDigit': response.presentedDigit,
      'respondedDigit': response.respondedDigit,
      'isCorrect': response.isCorrect,
      'reactionTimeMs': response.reactionTimeMs,
      'responseType': response.responseType.name,
    };
  }
}

/// データタイプ
enum DataType {
  imu,
  heartRate,
  nbackResponse,
  phaseError,
}

/// 同期統計
class SynchronizationStatistics {
  final Duration sessionDuration;
  final Map<String, int> dataCounters;
  final Map<String, double> dataRates;
  final Map<String, double> syncErrors;
  final int bufferSize;
  final Map<String, DateTime> lastTimestamps;
  
  SynchronizationStatistics({
    required this.sessionDuration,
    required this.dataCounters,
    required this.dataRates,
    required this.syncErrors,
    required this.bufferSize,
    required this.lastTimestamps,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'sessionDurationSeconds': sessionDuration.inSeconds,
      'dataCounters': dataCounters,
      'dataRates': dataRates,
      'syncErrors': syncErrors,
      'bufferSize': bufferSize,
      'lastTimestamps': lastTimestamps.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
    };
  }
}