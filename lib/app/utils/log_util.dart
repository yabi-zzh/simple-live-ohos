import 'package:logger/logger.dart';

class Log {
  /// 日志开关，打包前改为 false 即可关闭所有日志
  static bool enabled = true;

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      noBoxingByDefault: true,
    ),
  );

  static void d(String tag, String message) {
    if (!enabled) return;
    _logger.d('[$tag] $message');
  }

  static void i(String tag, String message) {
    if (!enabled) return;
    _logger.i('[$tag] $message');
  }

  static void w(String tag, String message) {
    if (!enabled) return;
    _logger.w('[$tag] $message');
  }

  static void e(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled) return;
    _logger.e('[$tag] $message', error: error, stackTrace: stackTrace);
  }
}
