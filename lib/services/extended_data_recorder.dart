import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'sensor_data_recorder.dart';
import 'phase_error_engine.dart';

/// 拡張データレコーダー
/// 可変難度・二重課題プロトコル用の追加メトリクスを記録
class ExtendedDataRecorder extends SensorDataRecorder {
  // 追加のエンジン
  final PhaseErrorEngine _phaseErrorEngine = PhaseErrorEngine();
  
  // ベースライン値の保存
  double? _baselineCv;
  final Map<String, double> _conditionCvValues = {};
  
  // 実験条件
  String _currentCondition = 'baseline';
  bool _isAdaptiveMode = true;
  
  // 追加メトリクスのバッファ
  final Queue<ExtendedMetrics> _metricsBuffer = Queue<ExtendedMetrics>();
  
  // CSV用の追加データ
  IOSink? _extendedFileSink;
  File? _extendedFile;
  
  /// 拡張記録セッションを開始
  @override
  Future<void> startRecording({
    required String sessionId,
    required String subjectId,
    Map<String, dynamic>? experimentMetadata,
  }) async {
    // 基本の記録開始
    await super.startRecording(
      sessionId: sessionId,
      subjectId: subjectId,
      experimentMetadata: experimentMetadata,
    );
    
    // 拡張ファイルの準備
    await _prepareExtendedFile(sessionId);
    
    // 実験条件の設定
    if (experimentMetadata != null) {
      _currentCondition = experimentMetadata['condition'] ?? 'baseline';
      _isAdaptiveMode = experimentMetadata['isAdaptive'] ?? true;
      
      // Phase Error Engineの初期化
      final targetSpm = experimentMetadata['targetSpm'] ?? 100.0;
      _phaseErrorEngine.initialize(targetSpm);
    }
  }
  
  /// 位相誤差を記録
  void recordPhaseError({
    required DateTime clickTime,
    required DateTime heelStrikeTime,
    required double currentSpm,
  }) {
    _phaseErrorEngine.recordPhaseError(
      clickTime: clickTime,
      heelStrikeTime: heelStrikeTime,
      currentSpm: currentSpm,
    );
  }
  
  /// CV値を記録（条件ごと）
  void recordCvValue(double cv) {
    if (_currentCondition == 'baseline' && _baselineCv == null) {
      _baselineCv = cv;
    }
    
    // 条件ごとの最新CV値を保存
    _conditionCvValues[_currentCondition] = cv;
  }
  
  /// 拡張メトリクスを記録
  void recordExtendedMetrics({
    required double currentSpm,
    required double currentCv,
    required double phaseCorrection,
    required double tempoAdjustment,
    Map<String, dynamic>? additionalData,
  }) {
    // deltaC と deltaR の計算
    double? deltaC;
    double? deltaR;
    
    if (_baselineCv != null) {
      // Fixed条件でのCV
      final fixedCv = _conditionCvValues['fixed'] ?? currentCv;
      
      // deltaC = CV_fixed - CV_baseline
      deltaC = fixedCv - _baselineCv!;
      
      // deltaR = CV_fixed - CV_adaptive
      if (_isAdaptiveMode) {
        deltaR = fixedCv - currentCv;
      }
    }
    
    // Phase Error Engineから統計情報を取得
    final phaseStats = _phaseErrorEngine.getStatistics();
    
    final metrics = ExtendedMetrics(
      timestamp: DateTime.now(),
      currentSpm: currentSpm,
      currentCv: currentCv,
      deltaC: deltaC,
      deltaR: deltaR,
      rmsePhi: phaseStats['rmsePhi'] as double,
      convergenceTimeTc: phaseStats['convergenceTime'] as double?,
      phaseCorrection: phaseCorrection,
      tempoAdjustment: tempoAdjustment,
      condition: _currentCondition,
      isAdaptive: _isAdaptiveMode,
      additionalData: additionalData,
    );
    
    _metricsBuffer.add(metrics);
    
    // バッファがいっぱいの場合はフラッシュ
    if (_metricsBuffer.length >= 100) {
      _flushExtendedBuffer();
    }
  }
  
  /// 実験条件を更新
  void updateCondition(String condition, bool isAdaptive) {
    _currentCondition = condition;
    _isAdaptiveMode = isAdaptive;
    
    // 条件変更時に自動的にメトリクスをフラッシュ
    _flushExtendedBuffer();
  }
  
  /// 拡張記録を停止
  @override
  Future<void> stopRecording() async {
    // 拡張バッファをフラッシュ
    await _flushExtendedBuffer();
    
    // 拡張ファイルを閉じる
    await _closeExtendedFile();
    
    // 基本の記録停止
    await super.stopRecording();
    
    // リセット
    _baselineCv = null;
    _conditionCvValues.clear();
    _currentCondition = 'baseline';
    _isAdaptiveMode = true;
  }
  
  /// 拡張ファイルパスを取得
  Future<String> getExtendedFilePath(String sessionId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/extended_metrics_$sessionId.csv';
  }
  
  // プライベートメソッド
  
  Future<void> _prepareExtendedFile(String sessionId) async {
    final filePath = await getExtendedFilePath(sessionId);
    _extendedFile = File(filePath);
    
    // 拡張CSVのヘッダー
    final header = [
      'timestamp_ms',
      'timestamp_iso',
      'condition',
      'is_adaptive',
      'current_spm',
      'current_cv',
      'delta_c',
      'delta_r',
      'rmse_phi',
      'convergence_time_tc',
      'phase_correction_gain',
      'tempo_adjustment',
      'additional_data_json',
    ];
    
    _extendedFileSink = _extendedFile!.openWrite();
    _extendedFileSink!.writeln(const ListToCsvConverter().convert([header]));
  }
  
  Future<void> _flushExtendedBuffer() async {
    if (_metricsBuffer.isEmpty || _extendedFileSink == null) return;
    
    try {
      // バッファからデータを取り出し
      final metricsToWrite = <ExtendedMetrics>[];
      while (_metricsBuffer.isNotEmpty) {
        metricsToWrite.add(_metricsBuffer.removeFirst());
      }
      
      // CSVデータに変換
      final csvData = _convertExtendedToCSV(metricsToWrite);
      
      // 非同期書き込み
      _extendedFileSink!.write(csvData);
      
    } catch (e) {
      // エラーハンドリング（親クラスのメソッドを使用）
      super.recordEvent(
        eventType: 'extended_flush_error',
        data: {'error': e.toString()},
      );
    }
  }
  
  String _convertExtendedToCSV(List<ExtendedMetrics> metrics) {
    final rows = metrics.map((m) {
      return [
        m.timestamp.millisecondsSinceEpoch,
        m.timestamp.toIso8601String(),
        m.condition,
        m.isAdaptive ? 1 : 0,
        m.currentSpm,
        m.currentCv,
        m.deltaC ?? '',
        m.deltaR ?? '',
        m.rmsePhi,
        m.convergenceTimeTc ?? '',
        m.phaseCorrection,
        m.tempoAdjustment,
        m.additionalData != null ? jsonEncode(m.additionalData) : '',
      ];
    }).toList();
    
    return '${const ListToCsvConverter().convert(rows)}\n';
  }
  
  Future<void> _closeExtendedFile() async {
    await _extendedFileSink?.flush();
    await _extendedFileSink?.close();
    _extendedFileSink = null;
    _extendedFile = null;
  }
  
  /// 統計サマリーを取得
  Map<String, dynamic> getExtendedStatistics() {
    final phaseStats = _phaseErrorEngine.getStatistics();
    
    return {
      'baselineCv': _baselineCv,
      'conditionCvValues': Map<String, double>.from(_conditionCvValues),
      'currentCondition': _currentCondition,
      'isAdaptive': _isAdaptiveMode,
      'phaseErrorStats': phaseStats,
      'metricsBufferSize': _metricsBuffer.length,
    };
  }
  
  /// Phase Error Engineへの直接アクセス（デバッグ用）
  PhaseErrorEngine get phaseErrorEngine => _phaseErrorEngine;
}

/// 拡張メトリクスのモデル
class ExtendedMetrics {
  final DateTime timestamp;
  final String condition;
  final bool isAdaptive;
  final double currentSpm;
  final double currentCv;
  final double? deltaC;
  final double? deltaR;
  final double rmsePhi;
  final double? convergenceTimeTc;
  final double phaseCorrection;
  final double tempoAdjustment;
  final Map<String, dynamic>? additionalData;
  
  ExtendedMetrics({
    required this.timestamp,
    required this.condition,
    required this.isAdaptive,
    required this.currentSpm,
    required this.currentCv,
    this.deltaC,
    this.deltaR,
    required this.rmsePhi,
    this.convergenceTimeTc,
    required this.phaseCorrection,
    required this.tempoAdjustment,
    this.additionalData,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'condition': condition,
      'isAdaptive': isAdaptive,
      'currentSpm': currentSpm,
      'currentCv': currentCv,
      'deltaC': deltaC,
      'deltaR': deltaR,
      'rmsePhi': rmsePhi,
      'convergenceTimeTc': convergenceTimeTc,
      'phaseCorrection': phaseCorrection,
      'tempoAdjustment': tempoAdjustment,
      'additionalData': additionalData,
    };
  }
}