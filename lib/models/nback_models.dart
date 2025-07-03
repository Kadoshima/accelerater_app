import 'dart:math' as math;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'nback_models.freezed.dart';
part 'nback_models.g.dart';

/// N-back課題の設定
@freezed
class NBackConfig with _$NBackConfig {
  const factory NBackConfig({
    required int nLevel, // 0, 1, 2
    @Default(30) int sequenceLength, // 数字列の長さ
    @Default(2000) int intervalMs, // 数字間隔（ミリ秒）
    @Default(1) int minDigit, // 最小数字
    @Default(9) int maxDigit, // 最大数字
    @Default('ja-JP') String language, // 言語設定
    @Default(1.0) double speechRate, // 音声速度
  }) = _NBackConfig;

  factory NBackConfig.fromJson(Map<String, dynamic> json) =>
      _$NBackConfigFromJson(json);
}

/// N-back課題の応答
@freezed
class NBackResponse with _$NBackResponse {
  const factory NBackResponse({
    required int sequenceIndex, // 数字列のインデックス
    required int presentedDigit, // 提示された数字
    int? respondedDigit, // 応答された数字
    required bool isCorrect, // 正解かどうか
    required DateTime timestamp, // 応答時刻
    int? reactionTimeMs, // 反応時間（ミリ秒）
    required ResponseType responseType, // 応答タイプ
  }) = _NBackResponse;

  factory NBackResponse.fromJson(Map<String, dynamic> json) =>
      _$NBackResponseFromJson(json);
}

/// 応答タイプ
enum ResponseType {
  voice, // 音声認識
  button, // ボタン入力
  timeout, // タイムアウト
  skipped, // スキップ
}

/// N-back課題のセッション
@freezed
class NBackSession with _$NBackSession {
  const factory NBackSession({
    required String sessionId,
    required NBackConfig config,
    required List<int> sequence, // 生成された数字列
    required List<NBackResponse> responses, // 応答リスト
    required DateTime startTime,
    DateTime? endTime,
    @Default(false) bool isCompleted,
  }) = _NBackSession;

  factory NBackSession.fromJson(Map<String, dynamic> json) =>
      _$NBackSessionFromJson(json);
}

/// N-backパフォーマンス統計
@freezed
class NBackPerformance with _$NBackPerformance {
  const NBackPerformance._();
  
  const factory NBackPerformance({
    required int totalTrials, // 総試行数
    required int correctResponses, // 正答数
    required int incorrectResponses, // 誤答数
    required int timeouts, // タイムアウト数
    required double accuracy, // 正答率（%）
    required double averageReactionTime, // 平均反応時間（ミリ秒）
    required double reactionTimeStd, // 反応時間の標準偏差
    Map<int, double>? rollingAccuracy, // 時間経過による正答率（1分ごと）
  }) = _NBackPerformance;

  factory NBackPerformance.fromJson(Map<String, dynamic> json) =>
      _$NBackPerformanceFromJson(json);
  
  /// セッションから統計を計算
  factory NBackPerformance.fromSession(NBackSession session) {
    final validResponses = session.responses
        .where((r) => r.responseType != ResponseType.skipped)
        .toList();
    
    final correctResponses = validResponses.where((r) => r.isCorrect).length;
    final incorrectResponses = validResponses.where((r) => !r.isCorrect && r.responseType != ResponseType.timeout).length;
    final timeouts = validResponses.where((r) => r.responseType == ResponseType.timeout).length;
    
    // 反応時間の計算
    final reactionTimes = validResponses
        .where((r) => r.reactionTimeMs != null)
        .map((r) => r.reactionTimeMs!.toDouble())
        .toList();
    
    double averageReactionTime = 0;
    double reactionTimeStd = 0;
    
    if (reactionTimes.isNotEmpty) {
      averageReactionTime = reactionTimes.reduce((a, b) => a + b) / reactionTimes.length;
      
      // 標準偏差の計算
      double sumSquaredDiff = 0;
      for (final rt in reactionTimes) {
        sumSquaredDiff += (rt - averageReactionTime) * (rt - averageReactionTime);
      }
      reactionTimeStd = reactionTimes.length > 1 
          ? math.sqrt(sumSquaredDiff / (reactionTimes.length - 1))
          : 0;
    }
    
    // 1分ごとの正答率を計算
    Map<int, double>? rollingAccuracy;
    if (session.startTime != null && validResponses.isNotEmpty) {
      rollingAccuracy = {};
      
      // 1分ごとにグループ化
      for (int minute = 0; minute <= 5; minute++) {
        final startWindow = session.startTime.add(Duration(minutes: minute));
        final endWindow = session.startTime.add(Duration(minutes: minute + 1));
        
        final windowResponses = validResponses.where((r) {
          return r.timestamp.isAfter(startWindow) && 
                 r.timestamp.isBefore(endWindow);
        }).toList();
        
        if (windowResponses.isNotEmpty) {
          final windowCorrect = windowResponses.where((r) => r.isCorrect).length;
          rollingAccuracy[minute] = (windowCorrect / windowResponses.length) * 100;
        }
      }
    }
    
    return NBackPerformance(
      totalTrials: validResponses.length,
      correctResponses: correctResponses,
      incorrectResponses: incorrectResponses,
      timeouts: timeouts,
      accuracy: validResponses.isEmpty ? 0 : (correctResponses / validResponses.length) * 100,
      averageReactionTime: averageReactionTime,
      reactionTimeStd: reactionTimeStd,
      rollingAccuracy: rollingAccuracy,
    );
  }
}

/// 実験セッションモデルの拡張
@freezed
class DualTaskExperimentSession with _$DualTaskExperimentSession {
  const factory DualTaskExperimentSession({
    required String sessionId,
    required String subjectId,
    required DateTime startTime,
    DateTime? endTime,
    
    // 実験条件
    required CognitiveLoad cognitiveLoad,
    required TempoControl tempoControl,
    
    // N-back課題データ
    NBackSession? nbackSession,
    
    // 歩行データ
    required double baselineSpm,
    double? targetSpm,
    double? averageSpm,
    double? cvBaseline,
    double? cvCondition,
    
    // 計算されたメトリクス
    double? deltaC,
    double? deltaR,
    double? rmsePhi,
    double? convergenceTimeTc,
    
    // メタデータ
    Map<String, dynamic>? metadata,
  }) = _DualTaskExperimentSession;

  factory DualTaskExperimentSession.fromJson(Map<String, dynamic> json) =>
      _$DualTaskExperimentSessionFromJson(json);
}

/// 認知負荷レベル
enum CognitiveLoad {
  none, // 認知負荷なし
  nBack0, // 0-back
  nBack1, // 1-back
  nBack2, // 2-back
}

/// テンポ制御モード
enum TempoControl {
  adaptive, // 適応的制御
  fixed, // 固定制御
}

// 拡張メソッド
extension CognitiveLoadExtension on CognitiveLoad {
  String get displayName {
    switch (this) {
      case CognitiveLoad.none:
        return 'No Task';
      case CognitiveLoad.nBack0:
        return '0-back';
      case CognitiveLoad.nBack1:
        return '1-back';
      case CognitiveLoad.nBack2:
        return '2-back';
    }
  }
  
  int? get nLevel {
    switch (this) {
      case CognitiveLoad.none:
        return null;
      case CognitiveLoad.nBack0:
        return 0;
      case CognitiveLoad.nBack1:
        return 1;
      case CognitiveLoad.nBack2:
        return 2;
    }
  }
}

extension TempoControlExtension on TempoControl {
  String get displayName {
    switch (this) {
      case TempoControl.adaptive:
        return 'Adaptive';
      case TempoControl.fixed:
        return 'Fixed';
    }
  }
}