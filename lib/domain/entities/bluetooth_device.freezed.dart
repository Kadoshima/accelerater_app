// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bluetooth_device.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$BluetoothDeviceEntity {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  BluetoothDeviceType get type => throw _privateConstructorUsedError;
  bool get isConnected => throw _privateConstructorUsedError;
  int? get rssi => throw _privateConstructorUsedError;
  Map<String, dynamic>? get manufacturerData =>
      throw _privateConstructorUsedError;

  /// Create a copy of BluetoothDeviceEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BluetoothDeviceEntityCopyWith<BluetoothDeviceEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BluetoothDeviceEntityCopyWith<$Res> {
  factory $BluetoothDeviceEntityCopyWith(BluetoothDeviceEntity value,
          $Res Function(BluetoothDeviceEntity) then) =
      _$BluetoothDeviceEntityCopyWithImpl<$Res, BluetoothDeviceEntity>;
  @useResult
  $Res call(
      {String id,
      String name,
      BluetoothDeviceType type,
      bool isConnected,
      int? rssi,
      Map<String, dynamic>? manufacturerData});
}

/// @nodoc
class _$BluetoothDeviceEntityCopyWithImpl<$Res,
        $Val extends BluetoothDeviceEntity>
    implements $BluetoothDeviceEntityCopyWith<$Res> {
  _$BluetoothDeviceEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BluetoothDeviceEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? isConnected = null,
    Object? rssi = freezed,
    Object? manufacturerData = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as BluetoothDeviceType,
      isConnected: null == isConnected
          ? _value.isConnected
          : isConnected // ignore: cast_nullable_to_non_nullable
              as bool,
      rssi: freezed == rssi
          ? _value.rssi
          : rssi // ignore: cast_nullable_to_non_nullable
              as int?,
      manufacturerData: freezed == manufacturerData
          ? _value.manufacturerData
          : manufacturerData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BluetoothDeviceEntityImplCopyWith<$Res>
    implements $BluetoothDeviceEntityCopyWith<$Res> {
  factory _$$BluetoothDeviceEntityImplCopyWith(
          _$BluetoothDeviceEntityImpl value,
          $Res Function(_$BluetoothDeviceEntityImpl) then) =
      __$$BluetoothDeviceEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      BluetoothDeviceType type,
      bool isConnected,
      int? rssi,
      Map<String, dynamic>? manufacturerData});
}

/// @nodoc
class __$$BluetoothDeviceEntityImplCopyWithImpl<$Res>
    extends _$BluetoothDeviceEntityCopyWithImpl<$Res,
        _$BluetoothDeviceEntityImpl>
    implements _$$BluetoothDeviceEntityImplCopyWith<$Res> {
  __$$BluetoothDeviceEntityImplCopyWithImpl(_$BluetoothDeviceEntityImpl _value,
      $Res Function(_$BluetoothDeviceEntityImpl) _then)
      : super(_value, _then);

  /// Create a copy of BluetoothDeviceEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? isConnected = null,
    Object? rssi = freezed,
    Object? manufacturerData = freezed,
  }) {
    return _then(_$BluetoothDeviceEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as BluetoothDeviceType,
      isConnected: null == isConnected
          ? _value.isConnected
          : isConnected // ignore: cast_nullable_to_non_nullable
              as bool,
      rssi: freezed == rssi
          ? _value.rssi
          : rssi // ignore: cast_nullable_to_non_nullable
              as int?,
      manufacturerData: freezed == manufacturerData
          ? _value._manufacturerData
          : manufacturerData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc

class _$BluetoothDeviceEntityImpl implements _BluetoothDeviceEntity {
  const _$BluetoothDeviceEntityImpl(
      {required this.id,
      required this.name,
      required this.type,
      required this.isConnected,
      this.rssi,
      final Map<String, dynamic>? manufacturerData})
      : _manufacturerData = manufacturerData;

  @override
  final String id;
  @override
  final String name;
  @override
  final BluetoothDeviceType type;
  @override
  final bool isConnected;
  @override
  final int? rssi;
  final Map<String, dynamic>? _manufacturerData;
  @override
  Map<String, dynamic>? get manufacturerData {
    final value = _manufacturerData;
    if (value == null) return null;
    if (_manufacturerData is EqualUnmodifiableMapView) return _manufacturerData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'BluetoothDeviceEntity(id: $id, name: $name, type: $type, isConnected: $isConnected, rssi: $rssi, manufacturerData: $manufacturerData)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BluetoothDeviceEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.isConnected, isConnected) ||
                other.isConnected == isConnected) &&
            (identical(other.rssi, rssi) || other.rssi == rssi) &&
            const DeepCollectionEquality()
                .equals(other._manufacturerData, _manufacturerData));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, name, type, isConnected,
      rssi, const DeepCollectionEquality().hash(_manufacturerData));

  /// Create a copy of BluetoothDeviceEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BluetoothDeviceEntityImplCopyWith<_$BluetoothDeviceEntityImpl>
      get copyWith => __$$BluetoothDeviceEntityImplCopyWithImpl<
          _$BluetoothDeviceEntityImpl>(this, _$identity);
}

abstract class _BluetoothDeviceEntity implements BluetoothDeviceEntity {
  const factory _BluetoothDeviceEntity(
          {required final String id,
          required final String name,
          required final BluetoothDeviceType type,
          required final bool isConnected,
          final int? rssi,
          final Map<String, dynamic>? manufacturerData}) =
      _$BluetoothDeviceEntityImpl;

  @override
  String get id;
  @override
  String get name;
  @override
  BluetoothDeviceType get type;
  @override
  bool get isConnected;
  @override
  int? get rssi;
  @override
  Map<String, dynamic>? get manufacturerData;

  /// Create a copy of BluetoothDeviceEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BluetoothDeviceEntityImplCopyWith<_$BluetoothDeviceEntityImpl>
      get copyWith => throw _privateConstructorUsedError;
}
