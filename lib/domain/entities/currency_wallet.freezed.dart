// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'currency_wallet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CurrencyWallet _$CurrencyWalletFromJson(Map<String, dynamic> json) {
  return _CurrencyWallet.fromJson(json);
}

/// @nodoc
mixin _$CurrencyWallet {
  String get id => throw _privateConstructorUsedError;
  String get currencyCode => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CurrencyWalletCopyWith<CurrencyWallet> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CurrencyWalletCopyWith<$Res> {
  factory $CurrencyWalletCopyWith(
          CurrencyWallet value, $Res Function(CurrencyWallet) then) =
      _$CurrencyWalletCopyWithImpl<$Res, CurrencyWallet>;
  @useResult
  $Res call(
      {String id,
      String currencyCode,
      String label,
      bool isActive,
      DateTime createdAt});
}

/// @nodoc
class _$CurrencyWalletCopyWithImpl<$Res, $Val extends CurrencyWallet>
    implements $CurrencyWalletCopyWith<$Res> {
  _$CurrencyWalletCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? currencyCode = null,
    Object? label = null,
    Object? isActive = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      currencyCode: null == currencyCode
          ? _value.currencyCode
          : currencyCode // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CurrencyWalletImplCopyWith<$Res>
    implements $CurrencyWalletCopyWith<$Res> {
  factory _$$CurrencyWalletImplCopyWith(_$CurrencyWalletImpl value,
          $Res Function(_$CurrencyWalletImpl) then) =
      __$$CurrencyWalletImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String currencyCode,
      String label,
      bool isActive,
      DateTime createdAt});
}

/// @nodoc
class __$$CurrencyWalletImplCopyWithImpl<$Res>
    extends _$CurrencyWalletCopyWithImpl<$Res, _$CurrencyWalletImpl>
    implements _$$CurrencyWalletImplCopyWith<$Res> {
  __$$CurrencyWalletImplCopyWithImpl(
      _$CurrencyWalletImpl _value, $Res Function(_$CurrencyWalletImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? currencyCode = null,
    Object? label = null,
    Object? isActive = null,
    Object? createdAt = null,
  }) {
    return _then(_$CurrencyWalletImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      currencyCode: null == currencyCode
          ? _value.currencyCode
          : currencyCode // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CurrencyWalletImpl implements _CurrencyWallet {
  const _$CurrencyWalletImpl(
      {required this.id,
      required this.currencyCode,
      required this.label,
      required this.isActive,
      required this.createdAt});

  factory _$CurrencyWalletImpl.fromJson(Map<String, dynamic> json) =>
      _$$CurrencyWalletImplFromJson(json);

  @override
  final String id;
  @override
  final String currencyCode;
  @override
  final String label;
  @override
  final bool isActive;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'CurrencyWallet(id: $id, currencyCode: $currencyCode, label: $label, isActive: $isActive, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CurrencyWalletImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, currencyCode, label, isActive, createdAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CurrencyWalletImplCopyWith<_$CurrencyWalletImpl> get copyWith =>
      __$$CurrencyWalletImplCopyWithImpl<_$CurrencyWalletImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CurrencyWalletImplToJson(
      this,
    );
  }
}

abstract class _CurrencyWallet implements CurrencyWallet {
  const factory _CurrencyWallet(
      {required final String id,
      required final String currencyCode,
      required final String label,
      required final bool isActive,
      required final DateTime createdAt}) = _$CurrencyWalletImpl;

  factory _CurrencyWallet.fromJson(Map<String, dynamic> json) =
      _$CurrencyWalletImpl.fromJson;

  @override
  String get id;
  @override
  String get currencyCode;
  @override
  String get label;
  @override
  bool get isActive;
  @override
  DateTime get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$CurrencyWalletImplCopyWith<_$CurrencyWalletImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
