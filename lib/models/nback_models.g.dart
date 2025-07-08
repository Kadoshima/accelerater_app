// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nback_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NBackConfigImpl _$$NBackConfigImplFromJson(Map<String, dynamic> json) =>
    _$NBackConfigImpl(
      nLevel: (json['nLevel'] as num).toInt(),
      sequenceLength: (json['sequenceLength'] as num?)?.toInt() ?? 30,
      intervalMs: (json['intervalMs'] as num?)?.toInt() ?? 2000,
      minDigit: (json['minDigit'] as num?)?.toInt() ?? 1,
      maxDigit: (json['maxDigit'] as num?)?.toInt() ?? 9,
      language: json['language'] as String? ?? 'ja-JP',
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 1.0,
    );

Map<String, dynamic> _$$NBackConfigImplToJson(_$NBackConfigImpl instance) =>
    <String, dynamic>{
      'nLevel': instance.nLevel,
      'sequenceLength': instance.sequenceLength,
      'intervalMs': instance.intervalMs,
      'minDigit': instance.minDigit,
      'maxDigit': instance.maxDigit,
      'language': instance.language,
      'speechRate': instance.speechRate,
    };

_$NBackResponseImpl _$$NBackResponseImplFromJson(Map<String, dynamic> json) =>
    _$NBackResponseImpl(
      sequenceIndex: (json['sequenceIndex'] as num).toInt(),
      presentedDigit: (json['presentedDigit'] as num).toInt(),
      respondedDigit: (json['respondedDigit'] as num?)?.toInt(),
      isCorrect: json['isCorrect'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      reactionTimeMs: (json['reactionTimeMs'] as num?)?.toInt(),
      responseType: $enumDecode(_$ResponseTypeEnumMap, json['responseType']),
    );

Map<String, dynamic> _$$NBackResponseImplToJson(_$NBackResponseImpl instance) =>
    <String, dynamic>{
      'sequenceIndex': instance.sequenceIndex,
      'presentedDigit': instance.presentedDigit,
      'respondedDigit': instance.respondedDigit,
      'isCorrect': instance.isCorrect,
      'timestamp': instance.timestamp.toIso8601String(),
      'reactionTimeMs': instance.reactionTimeMs,
      'responseType': _$ResponseTypeEnumMap[instance.responseType]!,
    };

const _$ResponseTypeEnumMap = {
  ResponseType.voice: 'voice',
  ResponseType.button: 'button',
  ResponseType.timeout: 'timeout',
  ResponseType.skipped: 'skipped',
};

_$NBackSessionImpl _$$NBackSessionImplFromJson(Map<String, dynamic> json) =>
    _$NBackSessionImpl(
      sessionId: json['sessionId'] as String,
      config: NBackConfig.fromJson(json['config'] as Map<String, dynamic>),
      sequence: (json['sequence'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      responses: (json['responses'] as List<dynamic>)
          .map((e) => NBackResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
    );

Map<String, dynamic> _$$NBackSessionImplToJson(_$NBackSessionImpl instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'config': instance.config,
      'sequence': instance.sequence,
      'responses': instance.responses,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
      'isCompleted': instance.isCompleted,
    };

_$NBackPerformanceImpl _$$NBackPerformanceImplFromJson(
        Map<String, dynamic> json) =>
    _$NBackPerformanceImpl(
      totalTrials: (json['totalTrials'] as num).toInt(),
      correctResponses: (json['correctResponses'] as num).toInt(),
      incorrectResponses: (json['incorrectResponses'] as num).toInt(),
      timeouts: (json['timeouts'] as num).toInt(),
      accuracy: (json['accuracy'] as num).toDouble(),
      averageReactionTime: (json['averageReactionTime'] as num).toDouble(),
      reactionTimeStd: (json['reactionTimeStd'] as num).toDouble(),
      rollingAccuracy: (json['rollingAccuracy'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(int.parse(k), (e as num).toDouble()),
      ),
    );

Map<String, dynamic> _$$NBackPerformanceImplToJson(
        _$NBackPerformanceImpl instance) =>
    <String, dynamic>{
      'totalTrials': instance.totalTrials,
      'correctResponses': instance.correctResponses,
      'incorrectResponses': instance.incorrectResponses,
      'timeouts': instance.timeouts,
      'accuracy': instance.accuracy,
      'averageReactionTime': instance.averageReactionTime,
      'reactionTimeStd': instance.reactionTimeStd,
      'rollingAccuracy':
          instance.rollingAccuracy?.map((k, e) => MapEntry(k.toString(), e)),
    };

_$DualTaskExperimentSessionImpl _$$DualTaskExperimentSessionImplFromJson(
        Map<String, dynamic> json) =>
    _$DualTaskExperimentSessionImpl(
      sessionId: json['sessionId'] as String,
      subjectId: json['subjectId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      cognitiveLoad: $enumDecode(_$CognitiveLoadEnumMap, json['cognitiveLoad']),
      tempoControl: $enumDecode(_$TempoControlEnumMap, json['tempoControl']),
      nbackSession: json['nbackSession'] == null
          ? null
          : NBackSession.fromJson(json['nbackSession'] as Map<String, dynamic>),
      baselineSpm: (json['baselineSpm'] as num).toDouble(),
      targetSpm: (json['targetSpm'] as num?)?.toDouble(),
      averageSpm: (json['averageSpm'] as num?)?.toDouble(),
      cvBaseline: (json['cvBaseline'] as num?)?.toDouble(),
      cvCondition: (json['cvCondition'] as num?)?.toDouble(),
      deltaC: (json['deltaC'] as num?)?.toDouble(),
      deltaR: (json['deltaR'] as num?)?.toDouble(),
      rmsePhi: (json['rmsePhi'] as num?)?.toDouble(),
      convergenceTimeTc: (json['convergenceTimeTc'] as num?)?.toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$DualTaskExperimentSessionImplToJson(
        _$DualTaskExperimentSessionImpl instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'subjectId': instance.subjectId,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
      'cognitiveLoad': _$CognitiveLoadEnumMap[instance.cognitiveLoad]!,
      'tempoControl': _$TempoControlEnumMap[instance.tempoControl]!,
      'nbackSession': instance.nbackSession,
      'baselineSpm': instance.baselineSpm,
      'targetSpm': instance.targetSpm,
      'averageSpm': instance.averageSpm,
      'cvBaseline': instance.cvBaseline,
      'cvCondition': instance.cvCondition,
      'deltaC': instance.deltaC,
      'deltaR': instance.deltaR,
      'rmsePhi': instance.rmsePhi,
      'convergenceTimeTc': instance.convergenceTimeTc,
      'metadata': instance.metadata,
    };

const _$CognitiveLoadEnumMap = {
  CognitiveLoad.none: 'none',
  CognitiveLoad.nBack0: 'nBack0',
  CognitiveLoad.nBack1: 'nBack1',
  CognitiveLoad.nBack2: 'nBack2',
};

const _$TempoControlEnumMap = {
  TempoControl.adaptive: 'adaptive',
  TempoControl.fixed: 'fixed',
};
