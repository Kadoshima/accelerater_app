// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'nback_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NBackConfig _$NBackConfigFromJson(Map<String, dynamic> json) {
  return _NBackConfig.fromJson(json);
}

/// @nodoc
mixin _$NBackConfig {
  int get nLevel => throw _privateConstructorUsedError; // 0, 1, 2
  int get sequenceLength => throw _privateConstructorUsedError; // 数字列の長さ
  int get intervalMs => throw _privateConstructorUsedError; // 数字間隔（ミリ秒）
  int get minDigit => throw _privateConstructorUsedError; // 最小数字
  int get maxDigit => throw _privateConstructorUsedError; // 最大数字
  String get language => throw _privateConstructorUsedError; // 言語設定
  double get speechRate => throw _privateConstructorUsedError;

  /// Serializes this NBackConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NBackConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NBackConfigCopyWith<NBackConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NBackConfigCopyWith<$Res> {
  factory $NBackConfigCopyWith(
          NBackConfig value, $Res Function(NBackConfig) then) =
      _$NBackConfigCopyWithImpl<$Res, NBackConfig>;
  @useResult
  $Res call(
      {int nLevel,
      int sequenceLength,
      int intervalMs,
      int minDigit,
      int maxDigit,
      String language,
      double speechRate});
}

/// @nodoc
class _$NBackConfigCopyWithImpl<$Res, $Val extends NBackConfig>
    implements $NBackConfigCopyWith<$Res> {
  _$NBackConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NBackConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nLevel = null,
    Object? sequenceLength = null,
    Object? intervalMs = null,
    Object? minDigit = null,
    Object? maxDigit = null,
    Object? language = null,
    Object? speechRate = null,
  }) {
    return _then(_value.copyWith(
      nLevel: null == nLevel
          ? _value.nLevel
          : nLevel // ignore: cast_nullable_to_non_nullable
              as int,
      sequenceLength: null == sequenceLength
          ? _value.sequenceLength
          : sequenceLength // ignore: cast_nullable_to_non_nullable
              as int,
      intervalMs: null == intervalMs
          ? _value.intervalMs
          : intervalMs // ignore: cast_nullable_to_non_nullable
              as int,
      minDigit: null == minDigit
          ? _value.minDigit
          : minDigit // ignore: cast_nullable_to_non_nullable
              as int,
      maxDigit: null == maxDigit
          ? _value.maxDigit
          : maxDigit // ignore: cast_nullable_to_non_nullable
              as int,
      language: null == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String,
      speechRate: null == speechRate
          ? _value.speechRate
          : speechRate // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NBackConfigImplCopyWith<$Res>
    implements $NBackConfigCopyWith<$Res> {
  factory _$$NBackConfigImplCopyWith(
          _$NBackConfigImpl value, $Res Function(_$NBackConfigImpl) then) =
      __$$NBackConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int nLevel,
      int sequenceLength,
      int intervalMs,
      int minDigit,
      int maxDigit,
      String language,
      double speechRate});
}

/// @nodoc
class __$$NBackConfigImplCopyWithImpl<$Res>
    extends _$NBackConfigCopyWithImpl<$Res, _$NBackConfigImpl>
    implements _$$NBackConfigImplCopyWith<$Res> {
  __$$NBackConfigImplCopyWithImpl(
      _$NBackConfigImpl _value, $Res Function(_$NBackConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of NBackConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nLevel = null,
    Object? sequenceLength = null,
    Object? intervalMs = null,
    Object? minDigit = null,
    Object? maxDigit = null,
    Object? language = null,
    Object? speechRate = null,
  }) {
    return _then(_$NBackConfigImpl(
      nLevel: null == nLevel
          ? _value.nLevel
          : nLevel // ignore: cast_nullable_to_non_nullable
              as int,
      sequenceLength: null == sequenceLength
          ? _value.sequenceLength
          : sequenceLength // ignore: cast_nullable_to_non_nullable
              as int,
      intervalMs: null == intervalMs
          ? _value.intervalMs
          : intervalMs // ignore: cast_nullable_to_non_nullable
              as int,
      minDigit: null == minDigit
          ? _value.minDigit
          : minDigit // ignore: cast_nullable_to_non_nullable
              as int,
      maxDigit: null == maxDigit
          ? _value.maxDigit
          : maxDigit // ignore: cast_nullable_to_non_nullable
              as int,
      language: null == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String,
      speechRate: null == speechRate
          ? _value.speechRate
          : speechRate // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NBackConfigImpl implements _NBackConfig {
  const _$NBackConfigImpl(
      {required this.nLevel,
      this.sequenceLength = 30,
      this.intervalMs = 2000,
      this.minDigit = 1,
      this.maxDigit = 9,
      this.language = 'ja-JP',
      this.speechRate = 1.0});

  factory _$NBackConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$NBackConfigImplFromJson(json);

  @override
  final int nLevel;
// 0, 1, 2
  @override
  @JsonKey()
  final int sequenceLength;
// 数字列の長さ
  @override
  @JsonKey()
  final int intervalMs;
// 数字間隔（ミリ秒）
  @override
  @JsonKey()
  final int minDigit;
// 最小数字
  @override
  @JsonKey()
  final int maxDigit;
// 最大数字
  @override
  @JsonKey()
  final String language;
// 言語設定
  @override
  @JsonKey()
  final double speechRate;

  @override
  String toString() {
    return 'NBackConfig(nLevel: $nLevel, sequenceLength: $sequenceLength, intervalMs: $intervalMs, minDigit: $minDigit, maxDigit: $maxDigit, language: $language, speechRate: $speechRate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NBackConfigImpl &&
            (identical(other.nLevel, nLevel) || other.nLevel == nLevel) &&
            (identical(other.sequenceLength, sequenceLength) ||
                other.sequenceLength == sequenceLength) &&
            (identical(other.intervalMs, intervalMs) ||
                other.intervalMs == intervalMs) &&
            (identical(other.minDigit, minDigit) ||
                other.minDigit == minDigit) &&
            (identical(other.maxDigit, maxDigit) ||
                other.maxDigit == maxDigit) &&
            (identical(other.language, language) ||
                other.language == language) &&
            (identical(other.speechRate, speechRate) ||
                other.speechRate == speechRate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, nLevel, sequenceLength,
      intervalMs, minDigit, maxDigit, language, speechRate);

  /// Create a copy of NBackConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NBackConfigImplCopyWith<_$NBackConfigImpl> get copyWith =>
      __$$NBackConfigImplCopyWithImpl<_$NBackConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NBackConfigImplToJson(
      this,
    );
  }
}

abstract class _NBackConfig implements NBackConfig {
  const factory _NBackConfig(
      {required final int nLevel,
      final int sequenceLength,
      final int intervalMs,
      final int minDigit,
      final int maxDigit,
      final String language,
      final double speechRate}) = _$NBackConfigImpl;

  factory _NBackConfig.fromJson(Map<String, dynamic> json) =
      _$NBackConfigImpl.fromJson;

  @override
  int get nLevel; // 0, 1, 2
  @override
  int get sequenceLength; // 数字列の長さ
  @override
  int get intervalMs; // 数字間隔（ミリ秒）
  @override
  int get minDigit; // 最小数字
  @override
  int get maxDigit; // 最大数字
  @override
  String get language; // 言語設定
  @override
  double get speechRate;

  /// Create a copy of NBackConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NBackConfigImplCopyWith<_$NBackConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NBackResponse _$NBackResponseFromJson(Map<String, dynamic> json) {
  return _NBackResponse.fromJson(json);
}

/// @nodoc
mixin _$NBackResponse {
  int get sequenceIndex => throw _privateConstructorUsedError; // 数字列のインデックス
  int get presentedDigit => throw _privateConstructorUsedError; // 提示された数字
  int? get respondedDigit => throw _privateConstructorUsedError; // 応答された数字
  bool get isCorrect => throw _privateConstructorUsedError; // 正解かどうか
  DateTime get timestamp => throw _privateConstructorUsedError; // 応答時刻
  int? get reactionTimeMs => throw _privateConstructorUsedError; // 反応時間（ミリ秒）
  ResponseType get responseType => throw _privateConstructorUsedError;

  /// Serializes this NBackResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NBackResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NBackResponseCopyWith<NBackResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NBackResponseCopyWith<$Res> {
  factory $NBackResponseCopyWith(
          NBackResponse value, $Res Function(NBackResponse) then) =
      _$NBackResponseCopyWithImpl<$Res, NBackResponse>;
  @useResult
  $Res call(
      {int sequenceIndex,
      int presentedDigit,
      int? respondedDigit,
      bool isCorrect,
      DateTime timestamp,
      int? reactionTimeMs,
      ResponseType responseType});
}

/// @nodoc
class _$NBackResponseCopyWithImpl<$Res, $Val extends NBackResponse>
    implements $NBackResponseCopyWith<$Res> {
  _$NBackResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NBackResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sequenceIndex = null,
    Object? presentedDigit = null,
    Object? respondedDigit = freezed,
    Object? isCorrect = null,
    Object? timestamp = null,
    Object? reactionTimeMs = freezed,
    Object? responseType = null,
  }) {
    return _then(_value.copyWith(
      sequenceIndex: null == sequenceIndex
          ? _value.sequenceIndex
          : sequenceIndex // ignore: cast_nullable_to_non_nullable
              as int,
      presentedDigit: null == presentedDigit
          ? _value.presentedDigit
          : presentedDigit // ignore: cast_nullable_to_non_nullable
              as int,
      respondedDigit: freezed == respondedDigit
          ? _value.respondedDigit
          : respondedDigit // ignore: cast_nullable_to_non_nullable
              as int?,
      isCorrect: null == isCorrect
          ? _value.isCorrect
          : isCorrect // ignore: cast_nullable_to_non_nullable
              as bool,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      reactionTimeMs: freezed == reactionTimeMs
          ? _value.reactionTimeMs
          : reactionTimeMs // ignore: cast_nullable_to_non_nullable
              as int?,
      responseType: null == responseType
          ? _value.responseType
          : responseType // ignore: cast_nullable_to_non_nullable
              as ResponseType,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NBackResponseImplCopyWith<$Res>
    implements $NBackResponseCopyWith<$Res> {
  factory _$$NBackResponseImplCopyWith(
          _$NBackResponseImpl value, $Res Function(_$NBackResponseImpl) then) =
      __$$NBackResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int sequenceIndex,
      int presentedDigit,
      int? respondedDigit,
      bool isCorrect,
      DateTime timestamp,
      int? reactionTimeMs,
      ResponseType responseType});
}

/// @nodoc
class __$$NBackResponseImplCopyWithImpl<$Res>
    extends _$NBackResponseCopyWithImpl<$Res, _$NBackResponseImpl>
    implements _$$NBackResponseImplCopyWith<$Res> {
  __$$NBackResponseImplCopyWithImpl(
      _$NBackResponseImpl _value, $Res Function(_$NBackResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of NBackResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sequenceIndex = null,
    Object? presentedDigit = null,
    Object? respondedDigit = freezed,
    Object? isCorrect = null,
    Object? timestamp = null,
    Object? reactionTimeMs = freezed,
    Object? responseType = null,
  }) {
    return _then(_$NBackResponseImpl(
      sequenceIndex: null == sequenceIndex
          ? _value.sequenceIndex
          : sequenceIndex // ignore: cast_nullable_to_non_nullable
              as int,
      presentedDigit: null == presentedDigit
          ? _value.presentedDigit
          : presentedDigit // ignore: cast_nullable_to_non_nullable
              as int,
      respondedDigit: freezed == respondedDigit
          ? _value.respondedDigit
          : respondedDigit // ignore: cast_nullable_to_non_nullable
              as int?,
      isCorrect: null == isCorrect
          ? _value.isCorrect
          : isCorrect // ignore: cast_nullable_to_non_nullable
              as bool,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      reactionTimeMs: freezed == reactionTimeMs
          ? _value.reactionTimeMs
          : reactionTimeMs // ignore: cast_nullable_to_non_nullable
              as int?,
      responseType: null == responseType
          ? _value.responseType
          : responseType // ignore: cast_nullable_to_non_nullable
              as ResponseType,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NBackResponseImpl implements _NBackResponse {
  const _$NBackResponseImpl(
      {required this.sequenceIndex,
      required this.presentedDigit,
      this.respondedDigit,
      required this.isCorrect,
      required this.timestamp,
      this.reactionTimeMs,
      required this.responseType});

  factory _$NBackResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$NBackResponseImplFromJson(json);

  @override
  final int sequenceIndex;
// 数字列のインデックス
  @override
  final int presentedDigit;
// 提示された数字
  @override
  final int? respondedDigit;
// 応答された数字
  @override
  final bool isCorrect;
// 正解かどうか
  @override
  final DateTime timestamp;
// 応答時刻
  @override
  final int? reactionTimeMs;
// 反応時間（ミリ秒）
  @override
  final ResponseType responseType;

  @override
  String toString() {
    return 'NBackResponse(sequenceIndex: $sequenceIndex, presentedDigit: $presentedDigit, respondedDigit: $respondedDigit, isCorrect: $isCorrect, timestamp: $timestamp, reactionTimeMs: $reactionTimeMs, responseType: $responseType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NBackResponseImpl &&
            (identical(other.sequenceIndex, sequenceIndex) ||
                other.sequenceIndex == sequenceIndex) &&
            (identical(other.presentedDigit, presentedDigit) ||
                other.presentedDigit == presentedDigit) &&
            (identical(other.respondedDigit, respondedDigit) ||
                other.respondedDigit == respondedDigit) &&
            (identical(other.isCorrect, isCorrect) ||
                other.isCorrect == isCorrect) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.reactionTimeMs, reactionTimeMs) ||
                other.reactionTimeMs == reactionTimeMs) &&
            (identical(other.responseType, responseType) ||
                other.responseType == responseType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, sequenceIndex, presentedDigit,
      respondedDigit, isCorrect, timestamp, reactionTimeMs, responseType);

  /// Create a copy of NBackResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NBackResponseImplCopyWith<_$NBackResponseImpl> get copyWith =>
      __$$NBackResponseImplCopyWithImpl<_$NBackResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NBackResponseImplToJson(
      this,
    );
  }
}

abstract class _NBackResponse implements NBackResponse {
  const factory _NBackResponse(
      {required final int sequenceIndex,
      required final int presentedDigit,
      final int? respondedDigit,
      required final bool isCorrect,
      required final DateTime timestamp,
      final int? reactionTimeMs,
      required final ResponseType responseType}) = _$NBackResponseImpl;

  factory _NBackResponse.fromJson(Map<String, dynamic> json) =
      _$NBackResponseImpl.fromJson;

  @override
  int get sequenceIndex; // 数字列のインデックス
  @override
  int get presentedDigit; // 提示された数字
  @override
  int? get respondedDigit; // 応答された数字
  @override
  bool get isCorrect; // 正解かどうか
  @override
  DateTime get timestamp; // 応答時刻
  @override
  int? get reactionTimeMs; // 反応時間（ミリ秒）
  @override
  ResponseType get responseType;

  /// Create a copy of NBackResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NBackResponseImplCopyWith<_$NBackResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NBackSession _$NBackSessionFromJson(Map<String, dynamic> json) {
  return _NBackSession.fromJson(json);
}

/// @nodoc
mixin _$NBackSession {
  String get sessionId => throw _privateConstructorUsedError;
  NBackConfig get config => throw _privateConstructorUsedError;
  List<int> get sequence => throw _privateConstructorUsedError; // 生成された数字列
  List<NBackResponse> get responses =>
      throw _privateConstructorUsedError; // 応答リスト
  DateTime get startTime => throw _privateConstructorUsedError;
  DateTime? get endTime => throw _privateConstructorUsedError;
  bool get isCompleted => throw _privateConstructorUsedError;

  /// Serializes this NBackSession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NBackSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NBackSessionCopyWith<NBackSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NBackSessionCopyWith<$Res> {
  factory $NBackSessionCopyWith(
          NBackSession value, $Res Function(NBackSession) then) =
      _$NBackSessionCopyWithImpl<$Res, NBackSession>;
  @useResult
  $Res call(
      {String sessionId,
      NBackConfig config,
      List<int> sequence,
      List<NBackResponse> responses,
      DateTime startTime,
      DateTime? endTime,
      bool isCompleted});

  $NBackConfigCopyWith<$Res> get config;
}

/// @nodoc
class _$NBackSessionCopyWithImpl<$Res, $Val extends NBackSession>
    implements $NBackSessionCopyWith<$Res> {
  _$NBackSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NBackSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? config = null,
    Object? sequence = null,
    Object? responses = null,
    Object? startTime = null,
    Object? endTime = freezed,
    Object? isCompleted = null,
  }) {
    return _then(_value.copyWith(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      config: null == config
          ? _value.config
          : config // ignore: cast_nullable_to_non_nullable
              as NBackConfig,
      sequence: null == sequence
          ? _value.sequence
          : sequence // ignore: cast_nullable_to_non_nullable
              as List<int>,
      responses: null == responses
          ? _value.responses
          : responses // ignore: cast_nullable_to_non_nullable
              as List<NBackResponse>,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  /// Create a copy of NBackSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NBackConfigCopyWith<$Res> get config {
    return $NBackConfigCopyWith<$Res>(_value.config, (value) {
      return _then(_value.copyWith(config: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$NBackSessionImplCopyWith<$Res>
    implements $NBackSessionCopyWith<$Res> {
  factory _$$NBackSessionImplCopyWith(
          _$NBackSessionImpl value, $Res Function(_$NBackSessionImpl) then) =
      __$$NBackSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String sessionId,
      NBackConfig config,
      List<int> sequence,
      List<NBackResponse> responses,
      DateTime startTime,
      DateTime? endTime,
      bool isCompleted});

  @override
  $NBackConfigCopyWith<$Res> get config;
}

/// @nodoc
class __$$NBackSessionImplCopyWithImpl<$Res>
    extends _$NBackSessionCopyWithImpl<$Res, _$NBackSessionImpl>
    implements _$$NBackSessionImplCopyWith<$Res> {
  __$$NBackSessionImplCopyWithImpl(
      _$NBackSessionImpl _value, $Res Function(_$NBackSessionImpl) _then)
      : super(_value, _then);

  /// Create a copy of NBackSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? config = null,
    Object? sequence = null,
    Object? responses = null,
    Object? startTime = null,
    Object? endTime = freezed,
    Object? isCompleted = null,
  }) {
    return _then(_$NBackSessionImpl(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      config: null == config
          ? _value.config
          : config // ignore: cast_nullable_to_non_nullable
              as NBackConfig,
      sequence: null == sequence
          ? _value._sequence
          : sequence // ignore: cast_nullable_to_non_nullable
              as List<int>,
      responses: null == responses
          ? _value._responses
          : responses // ignore: cast_nullable_to_non_nullable
              as List<NBackResponse>,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NBackSessionImpl implements _NBackSession {
  const _$NBackSessionImpl(
      {required this.sessionId,
      required this.config,
      required final List<int> sequence,
      required final List<NBackResponse> responses,
      required this.startTime,
      this.endTime,
      this.isCompleted = false})
      : _sequence = sequence,
        _responses = responses;

  factory _$NBackSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$NBackSessionImplFromJson(json);

  @override
  final String sessionId;
  @override
  final NBackConfig config;
  final List<int> _sequence;
  @override
  List<int> get sequence {
    if (_sequence is EqualUnmodifiableListView) return _sequence;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sequence);
  }

// 生成された数字列
  final List<NBackResponse> _responses;
// 生成された数字列
  @override
  List<NBackResponse> get responses {
    if (_responses is EqualUnmodifiableListView) return _responses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_responses);
  }

// 応答リスト
  @override
  final DateTime startTime;
  @override
  final DateTime? endTime;
  @override
  @JsonKey()
  final bool isCompleted;

  @override
  String toString() {
    return 'NBackSession(sessionId: $sessionId, config: $config, sequence: $sequence, responses: $responses, startTime: $startTime, endTime: $endTime, isCompleted: $isCompleted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NBackSessionImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.config, config) || other.config == config) &&
            const DeepCollectionEquality().equals(other._sequence, _sequence) &&
            const DeepCollectionEquality()
                .equals(other._responses, _responses) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      sessionId,
      config,
      const DeepCollectionEquality().hash(_sequence),
      const DeepCollectionEquality().hash(_responses),
      startTime,
      endTime,
      isCompleted);

  /// Create a copy of NBackSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NBackSessionImplCopyWith<_$NBackSessionImpl> get copyWith =>
      __$$NBackSessionImplCopyWithImpl<_$NBackSessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NBackSessionImplToJson(
      this,
    );
  }
}

abstract class _NBackSession implements NBackSession {
  const factory _NBackSession(
      {required final String sessionId,
      required final NBackConfig config,
      required final List<int> sequence,
      required final List<NBackResponse> responses,
      required final DateTime startTime,
      final DateTime? endTime,
      final bool isCompleted}) = _$NBackSessionImpl;

  factory _NBackSession.fromJson(Map<String, dynamic> json) =
      _$NBackSessionImpl.fromJson;

  @override
  String get sessionId;
  @override
  NBackConfig get config;
  @override
  List<int> get sequence; // 生成された数字列
  @override
  List<NBackResponse> get responses; // 応答リスト
  @override
  DateTime get startTime;
  @override
  DateTime? get endTime;
  @override
  bool get isCompleted;

  /// Create a copy of NBackSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NBackSessionImplCopyWith<_$NBackSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NBackPerformance _$NBackPerformanceFromJson(Map<String, dynamic> json) {
  return _NBackPerformance.fromJson(json);
}

/// @nodoc
mixin _$NBackPerformance {
  int get totalTrials => throw _privateConstructorUsedError; // 総試行数
  int get correctResponses => throw _privateConstructorUsedError; // 正答数
  int get incorrectResponses => throw _privateConstructorUsedError; // 誤答数
  int get timeouts => throw _privateConstructorUsedError; // タイムアウト数
  double get accuracy => throw _privateConstructorUsedError; // 正答率（%）
  double get averageReactionTime =>
      throw _privateConstructorUsedError; // 平均反応時間（ミリ秒）
  double get reactionTimeStd => throw _privateConstructorUsedError; // 反応時間の標準偏差
  Map<int, double>? get rollingAccuracy => throw _privateConstructorUsedError;

  /// Serializes this NBackPerformance to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NBackPerformance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NBackPerformanceCopyWith<NBackPerformance> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NBackPerformanceCopyWith<$Res> {
  factory $NBackPerformanceCopyWith(
          NBackPerformance value, $Res Function(NBackPerformance) then) =
      _$NBackPerformanceCopyWithImpl<$Res, NBackPerformance>;
  @useResult
  $Res call(
      {int totalTrials,
      int correctResponses,
      int incorrectResponses,
      int timeouts,
      double accuracy,
      double averageReactionTime,
      double reactionTimeStd,
      Map<int, double>? rollingAccuracy});
}

/// @nodoc
class _$NBackPerformanceCopyWithImpl<$Res, $Val extends NBackPerformance>
    implements $NBackPerformanceCopyWith<$Res> {
  _$NBackPerformanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NBackPerformance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalTrials = null,
    Object? correctResponses = null,
    Object? incorrectResponses = null,
    Object? timeouts = null,
    Object? accuracy = null,
    Object? averageReactionTime = null,
    Object? reactionTimeStd = null,
    Object? rollingAccuracy = freezed,
  }) {
    return _then(_value.copyWith(
      totalTrials: null == totalTrials
          ? _value.totalTrials
          : totalTrials // ignore: cast_nullable_to_non_nullable
              as int,
      correctResponses: null == correctResponses
          ? _value.correctResponses
          : correctResponses // ignore: cast_nullable_to_non_nullable
              as int,
      incorrectResponses: null == incorrectResponses
          ? _value.incorrectResponses
          : incorrectResponses // ignore: cast_nullable_to_non_nullable
              as int,
      timeouts: null == timeouts
          ? _value.timeouts
          : timeouts // ignore: cast_nullable_to_non_nullable
              as int,
      accuracy: null == accuracy
          ? _value.accuracy
          : accuracy // ignore: cast_nullable_to_non_nullable
              as double,
      averageReactionTime: null == averageReactionTime
          ? _value.averageReactionTime
          : averageReactionTime // ignore: cast_nullable_to_non_nullable
              as double,
      reactionTimeStd: null == reactionTimeStd
          ? _value.reactionTimeStd
          : reactionTimeStd // ignore: cast_nullable_to_non_nullable
              as double,
      rollingAccuracy: freezed == rollingAccuracy
          ? _value.rollingAccuracy
          : rollingAccuracy // ignore: cast_nullable_to_non_nullable
              as Map<int, double>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NBackPerformanceImplCopyWith<$Res>
    implements $NBackPerformanceCopyWith<$Res> {
  factory _$$NBackPerformanceImplCopyWith(_$NBackPerformanceImpl value,
          $Res Function(_$NBackPerformanceImpl) then) =
      __$$NBackPerformanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int totalTrials,
      int correctResponses,
      int incorrectResponses,
      int timeouts,
      double accuracy,
      double averageReactionTime,
      double reactionTimeStd,
      Map<int, double>? rollingAccuracy});
}

/// @nodoc
class __$$NBackPerformanceImplCopyWithImpl<$Res>
    extends _$NBackPerformanceCopyWithImpl<$Res, _$NBackPerformanceImpl>
    implements _$$NBackPerformanceImplCopyWith<$Res> {
  __$$NBackPerformanceImplCopyWithImpl(_$NBackPerformanceImpl _value,
      $Res Function(_$NBackPerformanceImpl) _then)
      : super(_value, _then);

  /// Create a copy of NBackPerformance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalTrials = null,
    Object? correctResponses = null,
    Object? incorrectResponses = null,
    Object? timeouts = null,
    Object? accuracy = null,
    Object? averageReactionTime = null,
    Object? reactionTimeStd = null,
    Object? rollingAccuracy = freezed,
  }) {
    return _then(_$NBackPerformanceImpl(
      totalTrials: null == totalTrials
          ? _value.totalTrials
          : totalTrials // ignore: cast_nullable_to_non_nullable
              as int,
      correctResponses: null == correctResponses
          ? _value.correctResponses
          : correctResponses // ignore: cast_nullable_to_non_nullable
              as int,
      incorrectResponses: null == incorrectResponses
          ? _value.incorrectResponses
          : incorrectResponses // ignore: cast_nullable_to_non_nullable
              as int,
      timeouts: null == timeouts
          ? _value.timeouts
          : timeouts // ignore: cast_nullable_to_non_nullable
              as int,
      accuracy: null == accuracy
          ? _value.accuracy
          : accuracy // ignore: cast_nullable_to_non_nullable
              as double,
      averageReactionTime: null == averageReactionTime
          ? _value.averageReactionTime
          : averageReactionTime // ignore: cast_nullable_to_non_nullable
              as double,
      reactionTimeStd: null == reactionTimeStd
          ? _value.reactionTimeStd
          : reactionTimeStd // ignore: cast_nullable_to_non_nullable
              as double,
      rollingAccuracy: freezed == rollingAccuracy
          ? _value._rollingAccuracy
          : rollingAccuracy // ignore: cast_nullable_to_non_nullable
              as Map<int, double>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NBackPerformanceImpl extends _NBackPerformance {
  const _$NBackPerformanceImpl(
      {required this.totalTrials,
      required this.correctResponses,
      required this.incorrectResponses,
      required this.timeouts,
      required this.accuracy,
      required this.averageReactionTime,
      required this.reactionTimeStd,
      final Map<int, double>? rollingAccuracy})
      : _rollingAccuracy = rollingAccuracy,
        super._();

  factory _$NBackPerformanceImpl.fromJson(Map<String, dynamic> json) =>
      _$$NBackPerformanceImplFromJson(json);

  @override
  final int totalTrials;
// 総試行数
  @override
  final int correctResponses;
// 正答数
  @override
  final int incorrectResponses;
// 誤答数
  @override
  final int timeouts;
// タイムアウト数
  @override
  final double accuracy;
// 正答率（%）
  @override
  final double averageReactionTime;
// 平均反応時間（ミリ秒）
  @override
  final double reactionTimeStd;
// 反応時間の標準偏差
  final Map<int, double>? _rollingAccuracy;
// 反応時間の標準偏差
  @override
  Map<int, double>? get rollingAccuracy {
    final value = _rollingAccuracy;
    if (value == null) return null;
    if (_rollingAccuracy is EqualUnmodifiableMapView) return _rollingAccuracy;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'NBackPerformance(totalTrials: $totalTrials, correctResponses: $correctResponses, incorrectResponses: $incorrectResponses, timeouts: $timeouts, accuracy: $accuracy, averageReactionTime: $averageReactionTime, reactionTimeStd: $reactionTimeStd, rollingAccuracy: $rollingAccuracy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NBackPerformanceImpl &&
            (identical(other.totalTrials, totalTrials) ||
                other.totalTrials == totalTrials) &&
            (identical(other.correctResponses, correctResponses) ||
                other.correctResponses == correctResponses) &&
            (identical(other.incorrectResponses, incorrectResponses) ||
                other.incorrectResponses == incorrectResponses) &&
            (identical(other.timeouts, timeouts) ||
                other.timeouts == timeouts) &&
            (identical(other.accuracy, accuracy) ||
                other.accuracy == accuracy) &&
            (identical(other.averageReactionTime, averageReactionTime) ||
                other.averageReactionTime == averageReactionTime) &&
            (identical(other.reactionTimeStd, reactionTimeStd) ||
                other.reactionTimeStd == reactionTimeStd) &&
            const DeepCollectionEquality()
                .equals(other._rollingAccuracy, _rollingAccuracy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      totalTrials,
      correctResponses,
      incorrectResponses,
      timeouts,
      accuracy,
      averageReactionTime,
      reactionTimeStd,
      const DeepCollectionEquality().hash(_rollingAccuracy));

  /// Create a copy of NBackPerformance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NBackPerformanceImplCopyWith<_$NBackPerformanceImpl> get copyWith =>
      __$$NBackPerformanceImplCopyWithImpl<_$NBackPerformanceImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NBackPerformanceImplToJson(
      this,
    );
  }
}

abstract class _NBackPerformance extends NBackPerformance {
  const factory _NBackPerformance(
      {required final int totalTrials,
      required final int correctResponses,
      required final int incorrectResponses,
      required final int timeouts,
      required final double accuracy,
      required final double averageReactionTime,
      required final double reactionTimeStd,
      final Map<int, double>? rollingAccuracy}) = _$NBackPerformanceImpl;
  const _NBackPerformance._() : super._();

  factory _NBackPerformance.fromJson(Map<String, dynamic> json) =
      _$NBackPerformanceImpl.fromJson;

  @override
  int get totalTrials; // 総試行数
  @override
  int get correctResponses; // 正答数
  @override
  int get incorrectResponses; // 誤答数
  @override
  int get timeouts; // タイムアウト数
  @override
  double get accuracy; // 正答率（%）
  @override
  double get averageReactionTime; // 平均反応時間（ミリ秒）
  @override
  double get reactionTimeStd; // 反応時間の標準偏差
  @override
  Map<int, double>? get rollingAccuracy;

  /// Create a copy of NBackPerformance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NBackPerformanceImplCopyWith<_$NBackPerformanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DualTaskExperimentSession _$DualTaskExperimentSessionFromJson(
    Map<String, dynamic> json) {
  return _DualTaskExperimentSession.fromJson(json);
}

/// @nodoc
mixin _$DualTaskExperimentSession {
  String get sessionId => throw _privateConstructorUsedError;
  String get subjectId => throw _privateConstructorUsedError;
  DateTime get startTime => throw _privateConstructorUsedError;
  DateTime? get endTime => throw _privateConstructorUsedError; // 実験条件
  CognitiveLoad get cognitiveLoad => throw _privateConstructorUsedError;
  TempoControl get tempoControl =>
      throw _privateConstructorUsedError; // N-back課題データ
  NBackSession? get nbackSession => throw _privateConstructorUsedError; // 歩行データ
  double get baselineSpm => throw _privateConstructorUsedError;
  double? get targetSpm => throw _privateConstructorUsedError;
  double? get averageSpm => throw _privateConstructorUsedError;
  double? get cvBaseline => throw _privateConstructorUsedError;
  double? get cvCondition => throw _privateConstructorUsedError; // 計算されたメトリクス
  double? get deltaC => throw _privateConstructorUsedError;
  double? get deltaR => throw _privateConstructorUsedError;
  double? get rmsePhi => throw _privateConstructorUsedError;
  double? get convergenceTimeTc => throw _privateConstructorUsedError; // メタデータ
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  /// Serializes this DualTaskExperimentSession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DualTaskExperimentSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DualTaskExperimentSessionCopyWith<DualTaskExperimentSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DualTaskExperimentSessionCopyWith<$Res> {
  factory $DualTaskExperimentSessionCopyWith(DualTaskExperimentSession value,
          $Res Function(DualTaskExperimentSession) then) =
      _$DualTaskExperimentSessionCopyWithImpl<$Res, DualTaskExperimentSession>;
  @useResult
  $Res call(
      {String sessionId,
      String subjectId,
      DateTime startTime,
      DateTime? endTime,
      CognitiveLoad cognitiveLoad,
      TempoControl tempoControl,
      NBackSession? nbackSession,
      double baselineSpm,
      double? targetSpm,
      double? averageSpm,
      double? cvBaseline,
      double? cvCondition,
      double? deltaC,
      double? deltaR,
      double? rmsePhi,
      double? convergenceTimeTc,
      Map<String, dynamic>? metadata});

  $NBackSessionCopyWith<$Res>? get nbackSession;
}

/// @nodoc
class _$DualTaskExperimentSessionCopyWithImpl<$Res,
        $Val extends DualTaskExperimentSession>
    implements $DualTaskExperimentSessionCopyWith<$Res> {
  _$DualTaskExperimentSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DualTaskExperimentSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? subjectId = null,
    Object? startTime = null,
    Object? endTime = freezed,
    Object? cognitiveLoad = null,
    Object? tempoControl = null,
    Object? nbackSession = freezed,
    Object? baselineSpm = null,
    Object? targetSpm = freezed,
    Object? averageSpm = freezed,
    Object? cvBaseline = freezed,
    Object? cvCondition = freezed,
    Object? deltaC = freezed,
    Object? deltaR = freezed,
    Object? rmsePhi = freezed,
    Object? convergenceTimeTc = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_value.copyWith(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      subjectId: null == subjectId
          ? _value.subjectId
          : subjectId // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cognitiveLoad: null == cognitiveLoad
          ? _value.cognitiveLoad
          : cognitiveLoad // ignore: cast_nullable_to_non_nullable
              as CognitiveLoad,
      tempoControl: null == tempoControl
          ? _value.tempoControl
          : tempoControl // ignore: cast_nullable_to_non_nullable
              as TempoControl,
      nbackSession: freezed == nbackSession
          ? _value.nbackSession
          : nbackSession // ignore: cast_nullable_to_non_nullable
              as NBackSession?,
      baselineSpm: null == baselineSpm
          ? _value.baselineSpm
          : baselineSpm // ignore: cast_nullable_to_non_nullable
              as double,
      targetSpm: freezed == targetSpm
          ? _value.targetSpm
          : targetSpm // ignore: cast_nullable_to_non_nullable
              as double?,
      averageSpm: freezed == averageSpm
          ? _value.averageSpm
          : averageSpm // ignore: cast_nullable_to_non_nullable
              as double?,
      cvBaseline: freezed == cvBaseline
          ? _value.cvBaseline
          : cvBaseline // ignore: cast_nullable_to_non_nullable
              as double?,
      cvCondition: freezed == cvCondition
          ? _value.cvCondition
          : cvCondition // ignore: cast_nullable_to_non_nullable
              as double?,
      deltaC: freezed == deltaC
          ? _value.deltaC
          : deltaC // ignore: cast_nullable_to_non_nullable
              as double?,
      deltaR: freezed == deltaR
          ? _value.deltaR
          : deltaR // ignore: cast_nullable_to_non_nullable
              as double?,
      rmsePhi: freezed == rmsePhi
          ? _value.rmsePhi
          : rmsePhi // ignore: cast_nullable_to_non_nullable
              as double?,
      convergenceTimeTc: freezed == convergenceTimeTc
          ? _value.convergenceTimeTc
          : convergenceTimeTc // ignore: cast_nullable_to_non_nullable
              as double?,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }

  /// Create a copy of DualTaskExperimentSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NBackSessionCopyWith<$Res>? get nbackSession {
    if (_value.nbackSession == null) {
      return null;
    }

    return $NBackSessionCopyWith<$Res>(_value.nbackSession!, (value) {
      return _then(_value.copyWith(nbackSession: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$DualTaskExperimentSessionImplCopyWith<$Res>
    implements $DualTaskExperimentSessionCopyWith<$Res> {
  factory _$$DualTaskExperimentSessionImplCopyWith(
          _$DualTaskExperimentSessionImpl value,
          $Res Function(_$DualTaskExperimentSessionImpl) then) =
      __$$DualTaskExperimentSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String sessionId,
      String subjectId,
      DateTime startTime,
      DateTime? endTime,
      CognitiveLoad cognitiveLoad,
      TempoControl tempoControl,
      NBackSession? nbackSession,
      double baselineSpm,
      double? targetSpm,
      double? averageSpm,
      double? cvBaseline,
      double? cvCondition,
      double? deltaC,
      double? deltaR,
      double? rmsePhi,
      double? convergenceTimeTc,
      Map<String, dynamic>? metadata});

  @override
  $NBackSessionCopyWith<$Res>? get nbackSession;
}

/// @nodoc
class __$$DualTaskExperimentSessionImplCopyWithImpl<$Res>
    extends _$DualTaskExperimentSessionCopyWithImpl<$Res,
        _$DualTaskExperimentSessionImpl>
    implements _$$DualTaskExperimentSessionImplCopyWith<$Res> {
  __$$DualTaskExperimentSessionImplCopyWithImpl(
      _$DualTaskExperimentSessionImpl _value,
      $Res Function(_$DualTaskExperimentSessionImpl) _then)
      : super(_value, _then);

  /// Create a copy of DualTaskExperimentSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? subjectId = null,
    Object? startTime = null,
    Object? endTime = freezed,
    Object? cognitiveLoad = null,
    Object? tempoControl = null,
    Object? nbackSession = freezed,
    Object? baselineSpm = null,
    Object? targetSpm = freezed,
    Object? averageSpm = freezed,
    Object? cvBaseline = freezed,
    Object? cvCondition = freezed,
    Object? deltaC = freezed,
    Object? deltaR = freezed,
    Object? rmsePhi = freezed,
    Object? convergenceTimeTc = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_$DualTaskExperimentSessionImpl(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      subjectId: null == subjectId
          ? _value.subjectId
          : subjectId // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cognitiveLoad: null == cognitiveLoad
          ? _value.cognitiveLoad
          : cognitiveLoad // ignore: cast_nullable_to_non_nullable
              as CognitiveLoad,
      tempoControl: null == tempoControl
          ? _value.tempoControl
          : tempoControl // ignore: cast_nullable_to_non_nullable
              as TempoControl,
      nbackSession: freezed == nbackSession
          ? _value.nbackSession
          : nbackSession // ignore: cast_nullable_to_non_nullable
              as NBackSession?,
      baselineSpm: null == baselineSpm
          ? _value.baselineSpm
          : baselineSpm // ignore: cast_nullable_to_non_nullable
              as double,
      targetSpm: freezed == targetSpm
          ? _value.targetSpm
          : targetSpm // ignore: cast_nullable_to_non_nullable
              as double?,
      averageSpm: freezed == averageSpm
          ? _value.averageSpm
          : averageSpm // ignore: cast_nullable_to_non_nullable
              as double?,
      cvBaseline: freezed == cvBaseline
          ? _value.cvBaseline
          : cvBaseline // ignore: cast_nullable_to_non_nullable
              as double?,
      cvCondition: freezed == cvCondition
          ? _value.cvCondition
          : cvCondition // ignore: cast_nullable_to_non_nullable
              as double?,
      deltaC: freezed == deltaC
          ? _value.deltaC
          : deltaC // ignore: cast_nullable_to_non_nullable
              as double?,
      deltaR: freezed == deltaR
          ? _value.deltaR
          : deltaR // ignore: cast_nullable_to_non_nullable
              as double?,
      rmsePhi: freezed == rmsePhi
          ? _value.rmsePhi
          : rmsePhi // ignore: cast_nullable_to_non_nullable
              as double?,
      convergenceTimeTc: freezed == convergenceTimeTc
          ? _value.convergenceTimeTc
          : convergenceTimeTc // ignore: cast_nullable_to_non_nullable
              as double?,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DualTaskExperimentSessionImpl implements _DualTaskExperimentSession {
  const _$DualTaskExperimentSessionImpl(
      {required this.sessionId,
      required this.subjectId,
      required this.startTime,
      this.endTime,
      required this.cognitiveLoad,
      required this.tempoControl,
      this.nbackSession,
      required this.baselineSpm,
      this.targetSpm,
      this.averageSpm,
      this.cvBaseline,
      this.cvCondition,
      this.deltaC,
      this.deltaR,
      this.rmsePhi,
      this.convergenceTimeTc,
      final Map<String, dynamic>? metadata})
      : _metadata = metadata;

  factory _$DualTaskExperimentSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$DualTaskExperimentSessionImplFromJson(json);

  @override
  final String sessionId;
  @override
  final String subjectId;
  @override
  final DateTime startTime;
  @override
  final DateTime? endTime;
// 実験条件
  @override
  final CognitiveLoad cognitiveLoad;
  @override
  final TempoControl tempoControl;
// N-back課題データ
  @override
  final NBackSession? nbackSession;
// 歩行データ
  @override
  final double baselineSpm;
  @override
  final double? targetSpm;
  @override
  final double? averageSpm;
  @override
  final double? cvBaseline;
  @override
  final double? cvCondition;
// 計算されたメトリクス
  @override
  final double? deltaC;
  @override
  final double? deltaR;
  @override
  final double? rmsePhi;
  @override
  final double? convergenceTimeTc;
// メタデータ
  final Map<String, dynamic>? _metadata;
// メタデータ
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'DualTaskExperimentSession(sessionId: $sessionId, subjectId: $subjectId, startTime: $startTime, endTime: $endTime, cognitiveLoad: $cognitiveLoad, tempoControl: $tempoControl, nbackSession: $nbackSession, baselineSpm: $baselineSpm, targetSpm: $targetSpm, averageSpm: $averageSpm, cvBaseline: $cvBaseline, cvCondition: $cvCondition, deltaC: $deltaC, deltaR: $deltaR, rmsePhi: $rmsePhi, convergenceTimeTc: $convergenceTimeTc, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DualTaskExperimentSessionImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.subjectId, subjectId) ||
                other.subjectId == subjectId) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.cognitiveLoad, cognitiveLoad) ||
                other.cognitiveLoad == cognitiveLoad) &&
            (identical(other.tempoControl, tempoControl) ||
                other.tempoControl == tempoControl) &&
            (identical(other.nbackSession, nbackSession) ||
                other.nbackSession == nbackSession) &&
            (identical(other.baselineSpm, baselineSpm) ||
                other.baselineSpm == baselineSpm) &&
            (identical(other.targetSpm, targetSpm) ||
                other.targetSpm == targetSpm) &&
            (identical(other.averageSpm, averageSpm) ||
                other.averageSpm == averageSpm) &&
            (identical(other.cvBaseline, cvBaseline) ||
                other.cvBaseline == cvBaseline) &&
            (identical(other.cvCondition, cvCondition) ||
                other.cvCondition == cvCondition) &&
            (identical(other.deltaC, deltaC) || other.deltaC == deltaC) &&
            (identical(other.deltaR, deltaR) || other.deltaR == deltaR) &&
            (identical(other.rmsePhi, rmsePhi) || other.rmsePhi == rmsePhi) &&
            (identical(other.convergenceTimeTc, convergenceTimeTc) ||
                other.convergenceTimeTc == convergenceTimeTc) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      sessionId,
      subjectId,
      startTime,
      endTime,
      cognitiveLoad,
      tempoControl,
      nbackSession,
      baselineSpm,
      targetSpm,
      averageSpm,
      cvBaseline,
      cvCondition,
      deltaC,
      deltaR,
      rmsePhi,
      convergenceTimeTc,
      const DeepCollectionEquality().hash(_metadata));

  /// Create a copy of DualTaskExperimentSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DualTaskExperimentSessionImplCopyWith<_$DualTaskExperimentSessionImpl>
      get copyWith => __$$DualTaskExperimentSessionImplCopyWithImpl<
          _$DualTaskExperimentSessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DualTaskExperimentSessionImplToJson(
      this,
    );
  }
}

abstract class _DualTaskExperimentSession implements DualTaskExperimentSession {
  const factory _DualTaskExperimentSession(
      {required final String sessionId,
      required final String subjectId,
      required final DateTime startTime,
      final DateTime? endTime,
      required final CognitiveLoad cognitiveLoad,
      required final TempoControl tempoControl,
      final NBackSession? nbackSession,
      required final double baselineSpm,
      final double? targetSpm,
      final double? averageSpm,
      final double? cvBaseline,
      final double? cvCondition,
      final double? deltaC,
      final double? deltaR,
      final double? rmsePhi,
      final double? convergenceTimeTc,
      final Map<String, dynamic>? metadata}) = _$DualTaskExperimentSessionImpl;

  factory _DualTaskExperimentSession.fromJson(Map<String, dynamic> json) =
      _$DualTaskExperimentSessionImpl.fromJson;

  @override
  String get sessionId;
  @override
  String get subjectId;
  @override
  DateTime get startTime;
  @override
  DateTime? get endTime; // 実験条件
  @override
  CognitiveLoad get cognitiveLoad;
  @override
  TempoControl get tempoControl; // N-back課題データ
  @override
  NBackSession? get nbackSession; // 歩行データ
  @override
  double get baselineSpm;
  @override
  double? get targetSpm;
  @override
  double? get averageSpm;
  @override
  double? get cvBaseline;
  @override
  double? get cvCondition; // 計算されたメトリクス
  @override
  double? get deltaC;
  @override
  double? get deltaR;
  @override
  double? get rmsePhi;
  @override
  double? get convergenceTimeTc; // メタデータ
  @override
  Map<String, dynamic>? get metadata;

  /// Create a copy of DualTaskExperimentSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DualTaskExperimentSessionImplCopyWith<_$DualTaskExperimentSessionImpl>
      get copyWith => throw _privateConstructorUsedError;
}
