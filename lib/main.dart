import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:js_executor_ohos/js_executor_impl.dart';
import 'package:js_executor_ohos/js_executor_ohos.dart';
import 'app/services/storage_service.dart';
import 'app/services/favorite_service.dart';
import 'app/services/history_service.dart';
import 'app/services/danmaku_settings_service.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/utils/log_util.dart';

/// MediaKit 是否可用（原生库是否加载成功）
bool isMediaKitAvailable = false;

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 日志开关，打包前改为 false
    Log.enabled = false;
    CoreLog.enableLog = false;

    // 全局错误处理
    FlutterError.onError = (details) {
      Log.e('Flutter', '未捕获的 Flutter 错误', details.exception, details.stack);
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      Log.e('Platform', '未捕获的平台错误', error, stack);
      return true;
    };

    // 降低图片缓存容量（从 200MB 降到 100MB）
    PaintingBinding.instance.imageCache.maximumSize = 200;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100MB

  // 尝试初始化 MediaKit，失败不影响应用启动
  try {
    MediaKit.ensureInitialized();
    isMediaKitAvailable = true;
    Log.i('App', 'MediaKit 初始化成功');
  } catch (e, stack) {
    isMediaKitAvailable = false;
    Log.e('App', 'MediaKit 初始化失败（播放功能不可用）', e, stack);
  }

  try {
    await initServices();
  } catch (e, stack) {
    Log.e('App', '初始化服务失败', e, stack);
  }

  runApp(const MyApp());
  }, (error, stack) {
    Log.e('Zone', '未捕获的异步错误', error, stack);
  });
}

Future<void> initServices() async {
  try {
    Log.i('App', '初始化服务...');

    // 1. 关键服务：必须同步等待（其他服务依赖它）
    await Get.putAsync(() => StorageService().init());

    // 2. 非关键服务：异步初始化，不阻塞启动
    Future.microtask(() async {
      await Get.putAsync(() => FavoriteService().init());
      await Get.putAsync(() => HistoryService().init());
      await Get.putAsync(() => DanmakuSettingsService().init());
      Log.i('App', '延迟服务初始化完成');
    });

    // 3. JsExecutor 延迟初始化（斗鱼/抖音签名需要）
    Future.microtask(() async {
      try {
        JsExecutorManager.setExecutor(JsExecutorOhosImpl());
        await JsExecutorOhos.init();
        Log.i('App', 'JsExecutor 初始化成功');
      } catch (e, stack) {
        Log.e('App', 'JsExecutor 初始化失败（斗鱼/抖音可能无法使用）', e, stack);
      }
    });

    Log.i('App', '关键服务初始化完成');
  } catch (e, stack) {
    Log.e('App', '服务初始化失败', e, stack);
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // 预计算主题，避免每次 build() 重复生成 ColorScheme
  static final _lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
  );
  static final _darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );

  /// 主题响应式状态，通过 builder 注入非动画 Theme 实现一帧切换，
  /// 绕过 MaterialApp 内置 AnimatedTheme 的多帧连续重建
  static final isDark = _readDarkMode().obs;

  static bool _readDarkMode() {
    try {
      final saved = StorageService.instance.getValue<String?>('theme_mode', null);
      if (saved == 'dark') return true;
      if (saved == 'light') return false;
    } catch (_) {}
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Simple Live',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: isDark.value ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        return Obx(() => Theme(
          data: isDark.value ? _darkTheme : _lightTheme,
          child: child!,
        ));
      },
      initialRoute: AppRoutes.index,
      getPages: AppPages.pages,
    );
  }
}
