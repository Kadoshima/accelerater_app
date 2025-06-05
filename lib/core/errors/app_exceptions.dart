/// アプリケーション固有の例外基底クラス
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => '${runtimeType}: $message ${code != null ? '(Code: $code)' : ''}';
}

/// Bluetooth関連の例外
class BluetoothException extends AppException {
  const BluetoothException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// デバイス接続の例外
class DeviceConnectionException extends BluetoothException {
  const DeviceConnectionException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// データ解析の例外
class DataParsingException extends AppException {
  const DataParsingException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// ストレージ関連の例外
class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// ネットワーク関連の例外
class NetworkException extends AppException {
  final int? statusCode;

  const NetworkException({
    required super.message,
    this.statusCode,
    super.code,
    super.originalError,
  });
}

/// 権限関連の例外
class PermissionException extends AppException {
  final String permissionType;

  const PermissionException({
    required super.message,
    required this.permissionType,
    super.code,
    super.originalError,
  });
}

/// 実験関連の例外
class ExperimentException extends AppException {
  const ExperimentException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// バリデーション関連の例外
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code,
    super.originalError,
  });
}