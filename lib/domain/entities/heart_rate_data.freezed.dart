// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'heart_rate_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$HeartRateData {
  int get heartRate => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  double? get energyExpended => throw _privateConstructorUsedError;
  List<int>? get rrIntervals => throw _privateConstructorUsedError;
  HeartRateDataSource get source => throw _privateConstructorUsedError;

  /// Create a copy of HeartRateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HeartRateDataCopyWith<HeartRateData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HeartRateDataCopyWith<$Res> {
  factory $HeartRateDataCopyWith(
          HeartRateData value, $Res Function(HeartRateData) then) =
      _$HeartRateDataCopyWithImpl<$Res, HeartRateData>;
  @useResult
  $Res call(
      {int heartRate,
      DateTime timestamp,
      double? energyExpended,
      List<int>? rrIntervals,
      HeartRateDataSource source});
}

/// @nodoc
class _$HeartRateDataCopyWithImpl<$Res, $Val extends HeartRateData>
    implements $HeartRateDataCopyWith<$Res> {
  _$HeartRateDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HeartRateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? heartRate = null,
    Object? timestamp = null,
    Object? energyExpended = freezed,
    Object? rrIntervals = freezed,
    Object? source = null,
  }) {
    return _then(_value.copyWith(
      heartRate: null == heartRate
          ? _value.heartRate
          : heartRate // ignore: cast_nullable_to_non_nullable
              as int,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      energyExpended: freezed == energyExpended
          ? _value.energyExpended
          : energyExpended // ignore: cast_nullable_to_non_nullable
              as double?,
      rrIntervals: freezed == rrIntervals
          ? _value.rrIntervals
          : rrIntervals // ignore: cast_nullable_to_non_nullable
              as List<int>?,
      source: null == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as HeartRateDataSource,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$HeartRateDataImplCopyWith<$Res>
    implements $HeartRateDataCopyWith<$Res> {
  factory _$$HeartRateDataImplCopyWith(
          _$HeartRateDataImpl value, $Res Function(_$HeartRateDataImpl) then) =
      __$$HeartRateDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int heartRate,
      DateTime timestamp,
      double? energyExpended,
      List<int>? rrIntervals,
      HeartRateDataSource source});
}

/// @nodoc
class __$$HeartRateDataImplCopyWithImpl<$Res>
    extends _$HeartRateDataCopyWithImpl<$Res, _$HeartRateDataImpl>
    implements _$$HeartRateDataImplCopyWith<$Res> {
  __$$HeartRateDataImplCopyWithImpl(
      _$HeartRateDataImpl _value, $Res Function(_$HeartRateDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of HeartRateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? heartRate = null,
    Object? timestamp = null,
    Object? energyExpended = freezed,
    Object? rrIntervals = freezed,
    Object? source = null,
  }) {
    return _then(_$HeartRateDataImpl(
      heartRate: null == heartRate
          ? _value.heartRate
          : heartRate // ignore: cast_nullable_to_non_nullable
              as int,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      energyExpended: freezed == energyExpended
          ? _value.energyExpended
          : energyExpended // ignore: cast_nullable_to_non_nullable
              as double?,
      rrIntervals: freezed == rrIntervals
          ? _value._rrIntervals
          : rrIntervals // ignore: cast_nullable_to_non_nullable
              as List<int>?,
      source: null == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as HeartRateDataSource,
    ));
  }
}

/// @nodoc

class _$HeartRateDataImpl implements _HeartRateData {
  const _$HeartRateDataImpl(
      {required this.heartRate,
      required this.timestamp,
      this.energyExpended,
      final List<int>? rrIntervals,
      required this.source})
      : _rrIntervals = rrIntervals;

  @override
  final int heartRate;
  @override
  final DateTime timestamp;
  @override
  final double? energyExpended;
  final List<int>? _rrIntervals;
  @override
  List<int>? get rrIntervals {
    final value = _rrIntervals;
    if (value == null) return null;
    if (_rrIntervals is EqualUnmodifiableListView) return _rrIntervals;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final HeartRateDataSource source;

  @override
  String toString() {
    return 'HeartRateData(heartRate: $heartRate, timestamp: $timestamp, energyExpended: $energyExpended, rrIntervals: $rrIntervals, source: $source)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HeartRateDataImpl &&
            (identical(other.heartRate, heartRate) ||
                other.heartRate == heartRate) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.energyExpended, energyExpended) ||
                other.energyExpended == energyExpended) &&
            const DeepCollectionEquality()
                .equals(other._rrIntervals, _rrIntervals) &&
            (identical(other.source, source) || other.source == source));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      heartRate,
      timestamp,
      energyExpended,
      const DeepCollectionEquality().hash(_rrIntervals),
      source);

  /// Create a copy of HeartRateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HeartRateDataImplCopyWith<_$HeartRateDataImpl> get copyWith =>
      __$$HeartRateDataImplCopyWithImpl<_$HeartRateDataImpl>(this, _$identity);
}

abstract class _HeartRateData implements HeartRateData {
  const factory _HeartRateData(
      {required final int heartRate,
      required final DateTime timestamp,
      final double? energyExpended,
      final List<int>? rrIntervals,
      required final HeartRateDataSource source}) = _$HeartRateDataImpl;

  @override
  int get heartRate;
  @override
  DateTime get timestamp;
  @override
  double? get energyExpended;
  @override
  List<int>? get rrIntervals;
  @override
  HeartRateDataSource get source;

  /// Create a copy of HeartRateData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HeartRateDataImplCopyWith<_$HeartRateDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
