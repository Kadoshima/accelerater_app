import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import '../core/storage/cloud_storage_interface.dart';
import '../core/utils/logger_service.dart';

/// データエクスポートサービス
/// 実験データをCSVまたはParquet形式でエクスポート
class DataExportService {
  final CloudStorageInterface? _cloudStorage;
  
  DataExportService({
    CloudStorageInterface? cloudStorage,
  }) : _cloudStorage = cloudStorage;
  
  /// セッションデータをCSV形式でエクスポート
  Future<Uint8List> exportSessionDataToCSV({
    required String participantId,
    required String sessionId,
    required DateTime sessionDate,
    required List<ExperimentDataRow> data,
  }) async {
    // ヘッダー行を定義
    final headers = [
      'Timestamp',
      'ExperimentPhase',
      'TargetSPM',
      'ActualSPM',
      'CV',
      'SampleEntropy',
      'PhaseRMSE',
      'StepCount',
      'NBackLevel',
      'NBackAccuracy',
      'ResponseTime',
      'SDNN',
      'HeartRate',
      'WalkingSpeed',
      'AccelX',
      'AccelY',
      'AccelZ',
      'GyroX',
      'GyroY',
      'GyroZ',
      'Notes',
    ];
    
    // データ行を作成
    final rows = <List<dynamic>>[headers];
    
    for (final row in data) {
      rows.add([
        row.timestamp.toIso8601String(),
        row.experimentPhase,
        row.targetSpm?.toStringAsFixed(1) ?? '',
        row.actualSpm?.toStringAsFixed(1) ?? '',
        row.cv?.toStringAsFixed(4) ?? '',
        row.sampleEntropy?.toStringAsFixed(4) ?? '',
        row.phaseRmse?.toStringAsFixed(2) ?? '',
        row.stepCount ?? '',
        row.nBackLevel ?? '',
        row.nBackAccuracy?.toStringAsFixed(2) ?? '',
        row.responseTimeMs ?? '',
        row.sdnn?.toStringAsFixed(2) ?? '',
        row.heartRate?.toStringAsFixed(1) ?? '',
        row.walkingSpeed?.toStringAsFixed(2) ?? '',
        row.accelX?.toStringAsFixed(4) ?? '',
        row.accelY?.toStringAsFixed(4) ?? '',
        row.accelZ?.toStringAsFixed(4) ?? '',
        row.gyroX?.toStringAsFixed(4) ?? '',
        row.gyroY?.toStringAsFixed(4) ?? '',
        row.gyroZ?.toStringAsFixed(4) ?? '',
        row.notes ?? '',
      ]);
    }
    
    // CSVに変換
    final csv = const ListToCsvConverter().convert(rows);
    return Uint8List.fromList(utf8.encode(csv));
  }
  
  /// サマリーデータをCSV形式でエクスポート
  Future<Uint8List> exportSummaryToCSV({
    required List<SessionSummary> summaries,
  }) async {
    final headers = [
      'ParticipantID',
      'SessionID',
      'SessionDate',
      'Phase',
      'Duration',
      'AvgSPM',
      'AvgCV',
      'AvgSampleEntropy',
      'ConvergenceTime',
      'TotalSteps',
      'AvgNBackAccuracy',
      'AvgResponseTime',
      'AvgSDNN',
      'AvgHeartRate',
      'AvgWalkingSpeed',
      'CeilingEffect',
      'RecoveryEffect',
      'NASATLXScore',
    ];
    
    final rows = <List<dynamic>>[headers];
    
    for (final summary in summaries) {
      rows.add([
        summary.participantId,
        summary.sessionId,
        summary.sessionDate.toIso8601String(),
        summary.phase,
        summary.duration.inSeconds,
        summary.avgSpm?.toStringAsFixed(1) ?? '',
        summary.avgCv?.toStringAsFixed(4) ?? '',
        summary.avgSampleEntropy?.toStringAsFixed(4) ?? '',
        summary.convergenceTime?.toStringAsFixed(1) ?? '',
        summary.totalSteps ?? '',
        summary.avgNBackAccuracy?.toStringAsFixed(2) ?? '',
        summary.avgResponseTime?.toStringAsFixed(0) ?? '',
        summary.avgSdnn?.toStringAsFixed(2) ?? '',
        summary.avgHeartRate?.toStringAsFixed(1) ?? '',
        summary.avgWalkingSpeed?.toStringAsFixed(2) ?? '',
        summary.ceilingEffect?.toStringAsFixed(4) ?? '',
        summary.recoveryEffect?.toStringAsFixed(4) ?? '',
        summary.nasaTlxScore?.toStringAsFixed(1) ?? '',
      ]);
    }
    
    final csv = const ListToCsvConverter().convert(rows);
    return Uint8List.fromList(utf8.encode(csv));
  }
  
  /// クラウドストレージにアップロード
  Future<String?> uploadToCloud({
    required String fileName,
    required Uint8List data,
    required Map<String, String> metadata,
  }) async {
    if (_cloudStorage == null) {
      logger.warning('Cloud storage not configured');
      return null;
    }
    
    try {
      final path = 'experiments/${DateTime.now().year}/$fileName';
      final url = await _cloudStorage!.uploadFile(
        path: path,
        data: data,
        metadata: metadata,
      );
      
      logger.info('Data uploaded successfully: $url');
      return url;
    } catch (e) {
      logger.error('Failed to upload data', e);
      return null;
    }
  }
  
  /// セッションデータをエクスポートしてアップロード
  Future<ExportResult> exportAndUploadSession({
    required String participantId,
    required String sessionId,
    required DateTime sessionDate,
    required List<ExperimentDataRow> data,
    required SessionSummary summary,
  }) async {
    try {
      // CSV形式でエクスポート
      final csvData = await exportSessionDataToCSV(
        participantId: participantId,
        sessionId: sessionId,
        sessionDate: sessionDate,
        data: data,
      );
      
      // ファイル名を生成
      final dateStr = sessionDate.toIso8601String().split('T')[0];
      final fileName = '${participantId}_${sessionId}_${dateStr}_raw.csv';
      
      // メタデータを準備
      final metadata = {
        'participantId': participantId,
        'sessionId': sessionId,
        'sessionDate': sessionDate.toIso8601String(),
        'dataType': 'raw',
        'format': 'csv',
        'rowCount': data.length.toString(),
      };
      
      // アップロード
      final url = await uploadToCloud(
        fileName: fileName,
        data: csvData,
        metadata: metadata,
      );
      
      return ExportResult(
        success: url != null,
        fileName: fileName,
        fileSize: csvData.length,
        uploadUrl: url,
        exportTime: DateTime.now(),
      );
    } catch (e) {
      logger.error('Failed to export and upload session', e);
      return ExportResult(
        success: false,
        fileName: '',
        fileSize: 0,
        uploadUrl: null,
        exportTime: DateTime.now(),
        error: e.toString(),
      );
    }
  }
}

/// 実験データの1行
class ExperimentDataRow {
  final DateTime timestamp;
  final String experimentPhase;
  final double? targetSpm;
  final double? actualSpm;
  final double? cv;
  final double? sampleEntropy;
  final double? phaseRmse;
  final int? stepCount;
  final int? nBackLevel;
  final double? nBackAccuracy;
  final int? responseTimeMs;
  final double? sdnn;
  final double? heartRate;
  final double? walkingSpeed;
  final double? accelX;
  final double? accelY;
  final double? accelZ;
  final double? gyroX;
  final double? gyroY;
  final double? gyroZ;
  final String? notes;
  
  ExperimentDataRow({
    required this.timestamp,
    required this.experimentPhase,
    this.targetSpm,
    this.actualSpm,
    this.cv,
    this.sampleEntropy,
    this.phaseRmse,
    this.stepCount,
    this.nBackLevel,
    this.nBackAccuracy,
    this.responseTimeMs,
    this.sdnn,
    this.heartRate,
    this.walkingSpeed,
    this.accelX,
    this.accelY,
    this.accelZ,
    this.gyroX,
    this.gyroY,
    this.gyroZ,
    this.notes,
  });
}

/// セッションサマリー
class SessionSummary {
  final String participantId;
  final String sessionId;
  final DateTime sessionDate;
  final String phase;
  final Duration duration;
  final double? avgSpm;
  final double? avgCv;
  final double? avgSampleEntropy;
  final double? convergenceTime;
  final int? totalSteps;
  final double? avgNBackAccuracy;
  final double? avgResponseTime;
  final double? avgSdnn;
  final double? avgHeartRate;
  final double? avgWalkingSpeed;
  final double? ceilingEffect;
  final double? recoveryEffect;
  final double? nasaTlxScore;
  
  SessionSummary({
    required this.participantId,
    required this.sessionId,
    required this.sessionDate,
    required this.phase,
    required this.duration,
    this.avgSpm,
    this.avgCv,
    this.avgSampleEntropy,
    this.convergenceTime,
    this.totalSteps,
    this.avgNBackAccuracy,
    this.avgResponseTime,
    this.avgSdnn,
    this.avgHeartRate,
    this.avgWalkingSpeed,
    this.ceilingEffect,
    this.recoveryEffect,
    this.nasaTlxScore,
  });
}

/// エクスポート結果
class ExportResult {
  final bool success;
  final String fileName;
  final int fileSize;
  final String? uploadUrl;
  final DateTime exportTime;
  final String? error;
  
  ExportResult({
    required this.success,
    required this.fileName,
    required this.fileSize,
    required this.uploadUrl,
    required this.exportTime,
    this.error,
  });
}