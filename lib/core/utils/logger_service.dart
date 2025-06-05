import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// アプリケーション全体で使用するロガーサービス
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  late final Logger _logger;

  void init() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: kDebugMode ? 2 : 0,
        errorMethodCount: kDebugMode ? 8 : 5,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      level: kDebugMode ? Level.debug : Level.info,
      filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
    );
  }

  void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  void wtf(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}

// グローバルロガーインスタンス
final logger = LoggerService();

// 便利な拡張メソッド
extension LoggerExtension on Object {
  void logDebug([String? message]) {
    logger.debug(message ?? toString());
  }

  void logInfo([String? message]) {
    logger.info(message ?? toString());
  }

  void logWarning([String? message]) {
    logger.warning(message ?? toString());
  }

  void logError([String? message, dynamic error, StackTrace? stackTrace]) {
    logger.error(message ?? toString(), error, stackTrace);
  }
}