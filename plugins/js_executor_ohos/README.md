# js_executor_ohos

HarmonyOS NEXT 平台的 JavaScript 执行器插件,使用 WebView 执行 JS 代码。

## 功能

- 执行任意 JavaScript 代码并返回结果
- 基于 `@ohos.web.webview` 的 `WebviewController.runJavaScript()` API
- 支持预初始化以减少首次执行延迟

## 使用方法

### 1. 初始化(可选)

```dart
import 'package:js_executor_ohos/js_executor_ohos.dart';

// 应用启动时预初始化 WebView
await JsExecutorOhos.init();
```

### 2. 执行 JS 代码

```dart
// 执行 JS 并获取返回值
final result = await JsExecutorOhos.execute('1 + 1');
print(result); // "2"

// 执行复杂 JS
final hash = await JsExecutorOhos.execute('''
  function md5(str) { /* ... */ }
  md5("hello");
''');
```

### 3. 释放资源(可选)

```dart
// 应用退出时释放 WebView
JsExecutorOhos.dispose();
```

## 集成到 simple_live_core

```dart
import 'package:simple_live_core/simple_live_core.dart';
import 'package:js_executor_ohos/js_executor_impl.dart';

// 设置 JsExecutor 实现
JsExecutorManager.setExecutor(JsExecutorOhosImpl());
await JsExecutorOhos.init();
```

## 技术实现

- **Dart 侧**: 通过 `MethodChannel('js_executor_ohos')` 与原生通信
- **ArkTS 侧**: 使用 `WebviewController` 加载 `about:blank` 页面,通过 `runJavaScript()` 执行代码
- **错误处理**: JS 执行错误会被捕获并通过 Promise reject 返回

## 注意事项

- WebView 需要先调用 `loadUrl()` 才能执行 `runJavaScript()`
- 首次执行会有约 100ms 的 WebView 初始化延迟
- JS 代码在独立的 WebView 上下文中执行,无法访问 DOM
- 返回值会被转换为字符串类型

## 依赖

- `@ohos/flutter_ohos`: Flutter OHOS 框架
- `@kit.ArkWeb`: HarmonyOS Web 组件库
