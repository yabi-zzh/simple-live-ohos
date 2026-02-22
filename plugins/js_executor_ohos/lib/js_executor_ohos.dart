import 'dart:async';
import 'package:flutter/services.dart';

/// HarmonyOS JS 执行器，通过 MethodChannel 调用原生 WebView 执行 JS
class JsExecutorOhos {
  static const MethodChannel _channel = MethodChannel('js_executor_ohos');

  /// 初始化 WebView（预加载，减少首次执行延迟）
  static Future<void> init() async {
    try {
      await _channel.invokeMethod('init');
    } catch (e) {
      // 初始化失败不阻塞，首次 execute 时会自动初始化
    }
  }

  /// 执行 JavaScript 代码并返回结果
  static Future<String> execute(String jsCode) async {
    final result = await _channel.invokeMethod<String>('execute', {
      'code': jsCode,
    });
    return result ?? '';
  }

  /// 释放 WebView 资源
  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } catch (_) {}
  }
}
