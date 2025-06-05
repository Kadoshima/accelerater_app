import 'package:fpdart/fpdart.dart';
import '../errors/app_exceptions.dart';

/// アプリケーション全体で使用する結果型のエイリアス
typedef Result<T> = Either<AppException, T>;

/// 結果型を生成するヘルパー関数
class Results {
  Results._();

  /// 成功結果を生成
  static Result<T> success<T>(T value) => Right(value);

  /// 失敗結果を生成
  static Result<T> failure<T>(AppException exception) => Left(exception);

  /// 非同期処理を安全に実行
  static Future<Result<T>> tryAsync<T>(
    Future<T> Function() operation, {
    AppException Function(dynamic error, StackTrace? stackTrace)? onError,
  }) async {
    try {
      final result = await operation();
      return success(result);
    } catch (error, stackTrace) {
      if (error is AppException) {
        return failure(error);
      }
      
      final exception = onError?.call(error, stackTrace) ??
          AppException(
            message: error.toString(),
            originalError: error,
          );
      return failure(exception);
    }
  }

  /// 同期処理を安全に実行
  static Result<T> trySync<T>(
    T Function() operation, {
    AppException Function(dynamic error, StackTrace? stackTrace)? onError,
  }) {
    try {
      final result = operation();
      return success(result);
    } catch (error, stackTrace) {
      if (error is AppException) {
        return failure(error);
      }
      
      final exception = onError?.call(error, stackTrace) ??
          AppException(
            message: error.toString(),
            originalError: error,
          );
      return failure(exception);
    }
  }
}