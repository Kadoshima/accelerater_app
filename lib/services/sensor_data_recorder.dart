import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import '../core/sensors/sensors.dart';
import '../core/plugins/research_plugin.dart';

/// センサーデータ記録サービス
/// 高頻度データの効率的な記録とリアルタイム同期を提供
class SensorDataRecorder {
  // バッファリング設定
  static const int _bufferSize = 1000; // 100Hz × 10秒分
  static const int _flushIntervalMs = 5000; // 5秒ごとにフラッシュ
  
  // データバッファ
  final Queue<RecordEntry> _dataBuffer = Queue<RecordEntry>();
  final Map<String, dynamic> _metadata = {};
  
  // ファイル管理
  String? _currentSessionId;
  File? _currentFile;
  IOSink? _fileSink;
  
  // タイマーとサブスクリプション
  Timer? _flushTimer;
  final Map<String, StreamSubscription> _subscriptions = {};
  
  // 同期処理
  final _syncController = StreamController<SyncEvent>.broadcast();
  Stream<SyncEvent> get syncEvents => _syncController.stream;
  
  // 統計情報
  int _totalRecordsWritten = 0;
  DateTime? _recordingStartTime;
  
  /// 記録セッションを開始
  Future<void> startRecording({
    required String sessionId,
    required String subjectId,
    Map<String, dynamic>? experimentMetadata,
  }) async {
    if (_currentSessionId != null) {
      await stopRecording();
    }
    
    _currentSessionId = sessionId;
    _recordingStartTime = DateTime.now();
    
    // メタデータの設定
    _metadata.clear();
    _metadata.addAll({
      'sessionId': sessionId,
      'subjectId': subjectId,
      'startTime': _recordingStartTime!.toIso8601String(),
      'samplingRates': {
        'imu': 100, // Hz
        'heartRate': 1, // Hz
        'nback': 'event-based',
      },
      ...?experimentMetadata,
    });
    
    // ファイルの準備
    await _prepareFile();
    
    // フラッシュタイマーの開始
    _flushTimer = Timer.periodic(
      Duration(milliseconds: _flushIntervalMs),
      (_) => _flushBuffer(),
    );
    
    _syncController.add(SyncEvent(
      type: SyncEventType.started,
      timestamp: DateTime.now(),
      message: 'Recording started: $sessionId',
    ));
  }
  
  /// センサーを記録対象に追加
  void addSensor(ISensor sensor) {
    final key = '${sensor.type.name}_${sensor.id}';
    
    // 既存のサブスクリプションがあれば削除
    _subscriptions[key]?.cancel();
    
    // データストリームを購読
    _subscriptions[key] = sensor.dataStream.listen(
      (data) => _handleSensorData(sensor, data),
      onError: (error) => _handleError(error, sensor.id),
    );
  }
  
  /// センサーを記録対象から削除
  void removeSensor(ISensor sensor) {
    final key = '${sensor.type.name}_${sensor.id}';
    _subscriptions[key]?.cancel();
    _subscriptions.remove(key);
  }
  
  /// 手動でイベントを記録（N-back応答など）
  void recordEvent({
    required String eventType,
    required Map<String, dynamic> data,
    String? sensorId,
  }) {
    final entry = RecordEntry(
      timestamp: DateTime.now(),
      sensorType: 'event',
      sensorId: sensorId ?? 'manual',
      data: {
        'eventType': eventType,
        ...data,
      },
    );
    
    _addToBuffer(entry);
  }
  
  /// 記録を停止
  Future<void> stopRecording() async {
    // タイマーの停止
    _flushTimer?.cancel();
    _flushTimer = null;
    
    // サブスクリプションの解除
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    // 残りのバッファをフラッシュ
    await _flushBuffer();
    
    // ファイルのクローズ
    await _closeFile();
    
    // メタデータの保存
    if (_currentSessionId != null) {
      await _saveMetadata();
    }
    
    _syncController.add(SyncEvent(
      type: SyncEventType.stopped,
      timestamp: DateTime.now(),
      message: 'Recording stopped. Total records: $_totalRecordsWritten',
    ));
    
    // リセット
    _currentSessionId = null;
    _totalRecordsWritten = 0;
    _recordingStartTime = null;
  }
  
  /// 記録状態を取得
  RecordingStatus get status => RecordingStatus(
    isRecording: _currentSessionId != null,
    sessionId: _currentSessionId,
    bufferSize: _dataBuffer.length,
    totalRecordsWritten: _totalRecordsWritten,
    recordingDuration: _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!)
        : null,
  );
  
  /// ファイルパスを取得
  Future<String> getFilePath(String sessionId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/sensor_data_$sessionId.csv';
  }
  
  /// メタデータファイルパスを取得
  Future<String> getMetadataPath(String sessionId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/metadata_$sessionId.json';
  }
  
  // プライベートメソッド
  
  void _handleSensorData(ISensor sensor, SensorData data) {
    final entry = RecordEntry(
      timestamp: data.timestamp,
      sensorType: sensor.type.name,
      sensorId: sensor.id,
      data: _extractSensorData(data),
    );
    
    _addToBuffer(entry);
  }
  
  Map<String, dynamic> _extractSensorData(SensorData data) {
    if (data is AccelerometerData) {
      return {
        'x': data.x,
        'y': data.y,
        'z': data.z,
        'magnitude': data.magnitude,
      };
    } else if (data is GyroscopeData) {
      return {
        'x': data.x,
        'y': data.y,
        'z': data.z,
        'magnitude': data.magnitude,
      };
    } else if (data is MagnetometerData) {
      return {
        'x': data.x,
        'y': data.y,
        'z': data.z,
        'magnitude': data.magnitude,
      };
    } else if (data is HeartRateData) {
      return {
        'bpm': data.bpm,
        'confidence': data.confidence,
        'rrIntervals': data.rrIntervals,
      };
    } else if (data is IMUData) {
      final result = <String, dynamic>{};
      if (data.accelerometer != null) {
        result['accelerometer'] = _extractSensorData(data.accelerometer!);
      }
      if (data.gyroscope != null) {
        result['gyroscope'] = _extractSensorData(data.gyroscope!);
      }
      if (data.magnetometer != null) {
        result['magnetometer'] = _extractSensorData(data.magnetometer!);
      }
      return result;
    }
    
    // デフォルト
    return {'raw': data.toString()};
  }
  
  void _addToBuffer(RecordEntry entry) {
    _dataBuffer.add(entry);
    
    // バッファがいっぱいの場合は即座にフラッシュ
    if (_dataBuffer.length >= _bufferSize) {
      _flushBuffer();
    }
  }
  
  Future<void> _flushBuffer() async {
    if (_dataBuffer.isEmpty || _fileSink == null) return;
    
    try {
      // バッファからデータを取り出し
      final entriesToWrite = <RecordEntry>[];
      while (_dataBuffer.isNotEmpty && entriesToWrite.length < _bufferSize) {
        entriesToWrite.add(_dataBuffer.removeFirst());
      }
      
      // CSVデータに変換
      final csvData = _convertToCSV(entriesToWrite);
      
      // 非同期書き込み
      _fileSink!.write(csvData);
      
      _totalRecordsWritten += entriesToWrite.length;
      
      _syncController.add(SyncEvent(
        type: SyncEventType.flushed,
        timestamp: DateTime.now(),
        message: 'Flushed ${entriesToWrite.length} records',
        data: {'totalWritten': _totalRecordsWritten},
      ));
    } catch (e) {
      _handleError(e, 'flush_buffer');
    }
  }
  
  String _convertToCSV(List<RecordEntry> entries) {
    final rows = entries.map((entry) {
      return [
        entry.timestamp.millisecondsSinceEpoch,
        entry.timestamp.toIso8601String(),
        entry.sensorType,
        entry.sensorId,
        jsonEncode(entry.data),
      ];
    }).toList();
    
    return '${const ListToCsvConverter().convert(rows)}\n';
  }
  
  Future<void> _prepareFile() async {
    final filePath = await getFilePath(_currentSessionId!);
    _currentFile = File(filePath);
    
    // ヘッダーを書き込み
    final header = [
      'timestamp_ms',
      'timestamp_iso',
      'sensor_type',
      'sensor_id',
      'data_json',
    ];
    
    _fileSink = _currentFile!.openWrite();
    _fileSink!.writeln(const ListToCsvConverter().convert([header]));
  }
  
  Future<void> _closeFile() async {
    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;
    _currentFile = null;
  }
  
  Future<void> _saveMetadata() async {
    final metadataPath = await getMetadataPath(_currentSessionId!);
    final metadataFile = File(metadataPath);
    
    _metadata['endTime'] = DateTime.now().toIso8601String();
    _metadata['totalRecords'] = _totalRecordsWritten;
    _metadata['recordingDuration'] = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!).inSeconds
        : 0;
    
    await metadataFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_metadata),
    );
  }
  
  void _handleError(dynamic error, String source) {
    _syncController.add(SyncEvent(
      type: SyncEventType.error,
      timestamp: DateTime.now(),
      message: 'Error in $source: $error',
      error: error,
    ));
  }
  
  void dispose() {
    stopRecording();
    _syncController.close();
  }
}

/// 記録エントリ
class RecordEntry {
  final DateTime timestamp;
  final String sensorType;
  final String sensorId;
  final Map<String, dynamic> data;
  
  RecordEntry({
    required this.timestamp,
    required this.sensorType,
    required this.sensorId,
    required this.data,
  });
}

/// 記録状態
class RecordingStatus {
  final bool isRecording;
  final String? sessionId;
  final int bufferSize;
  final int totalRecordsWritten;
  final Duration? recordingDuration;
  
  RecordingStatus({
    required this.isRecording,
    this.sessionId,
    required this.bufferSize,
    required this.totalRecordsWritten,
    this.recordingDuration,
  });
}

/// 同期イベント
class SyncEvent {
  final SyncEventType type;
  final DateTime timestamp;
  final String message;
  final Map<String, dynamic>? data;
  final dynamic error;
  
  SyncEvent({
    required this.type,
    required this.timestamp,
    required this.message,
    this.data,
    this.error,
  });
}

/// 同期イベントタイプ
enum SyncEventType {
  started,
  stopped,
  flushed,
  error,
}