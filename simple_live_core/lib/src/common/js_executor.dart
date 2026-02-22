/// JS 执行器抽象接口
///
/// 用于执行 JavaScript 代码并返回结果。
/// 由于 dart_quickjs 在鸿蒙上不可用，需要由 APP 层提供具体实现。
/// 鸿蒙平台可通过 WebView 或其他方式执行 JS。
abstract class JsExecutor {
  /// 执行 JavaScript 代码并返回结果
  ///
  /// [jsCode] 要执行的 JavaScript 代码
  /// 返回执行结果的字符串表示
  Future<String> execute(String jsCode);

  /// 释放资源（如果需要）
  void dispose() {}
}

/// JS 执行器管理器
///
/// 全局单例，由 APP 层在启动时注入具体实现
class JsExecutorManager {
  static JsExecutor? _instance;

  /// 设置 JS 执行器实现
  static void setExecutor(JsExecutor executor) {
    _instance = executor;
  }

  /// 获取 JS 执行器实例
  ///
  /// 如果未初始化会抛出异常
  static JsExecutor get instance {
    if (_instance == null) {
      throw StateError(
        'JsExecutor not initialized. '
        'Please call JsExecutorManager.setExecutor() in your app initialization.',
      );
    }
    return _instance!;
  }

  /// 检查是否已初始化
  static bool get isInitialized => _instance != null;
}
