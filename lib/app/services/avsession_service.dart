import 'dart:async';
import 'package:flutter/services.dart';
import '../utils/log_util.dart';

/// 系统播控命令类型
enum AVSessionCommand { play, pause, stop }

/// AVSession 服务 - 管理 HarmonyOS 媒体会话
///
/// 通过 MethodChannel 调用 OHOS 原生 AVSession API，
/// 通过 EventChannel 接收系统播控命令（锁屏/通知栏的播放/暂停操作）。
class AVSessionService {
  static const _methodChannel = MethodChannel('com.simplelive/avsession');
  static const _eventChannel = EventChannel('com.simplelive/avsession_events');

  static final AVSessionService _instance = AVSessionService._();
  static AVSessionService get instance => _instance;
  AVSessionService._();

  StreamSubscription? _eventSubscription;
  bool _isActive = false;

  /// 系统播控命令回调
  void Function(AVSessionCommand command)? onCommand;

  /// 当前是否处于激活状态
  bool get isActive => _isActive;

  /// 激活 AVSession + 启动长时任务
  Future<void> activate({
    required String title,
    required String artist,
    String mediaImage = '',
    String assetId = '0',
  }) async {
    // 清理可能存在的旧会话
    if (_isActive) {
      await deactivate();
    }
    try {
      await _methodChannel.invokeMethod('activate', {
        'title': title,
        'artist': artist,
        'mediaImage': mediaImage,
        'assetId': assetId,
      });
      _isActive = true;
      _listenEvents();
      Log.i('AVSession', '会话已激活: $title - $artist');
    } catch (e) {
      Log.e('AVSession', '激活失败: $e');
    }
  }

  /// 更新媒体元数据
  Future<void> updateMetadata({
    required String title,
    required String artist,
    String mediaImage = '',
    String assetId = '0',
  }) async {
    if (!_isActive) return;
    try {
      await _methodChannel.invokeMethod('updateMetadata', {
        'title': title,
        'artist': artist,
        'mediaImage': mediaImage,
        'assetId': assetId,
      });
    } catch (e) {
      Log.w('AVSession', '更新元数据失败: $e');
    }
  }

  /// 更新播放状态
  /// [state] 0=播放, 1=暂停, 2=停止
  Future<void> updatePlaybackState(int state) async {
    if (!_isActive) return;
    try {
      await _methodChannel.invokeMethod('updatePlaybackState', {
        'state': state,
      });
    } catch (e) {
      Log.w('AVSession', '更新播放状态失败: $e');
    }
  }

  /// 停用 AVSession + 停止长时任务
  Future<void> deactivate() async {
    if (!_isActive) return;
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _isActive = false;
    onCommand = null;
    try {
      await _methodChannel.invokeMethod('deactivate');
      Log.i('AVSession', '会话已停用');
    } catch (e) {
      Log.w('AVSession', '停用失败: $e');
    }
  }

  /// 监听来自系统播控中心的命令
  void _listenEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        final cmd = _parseCommand(event as String);
        if (cmd != null) {
          Log.d('AVSession', '收到系统命令: $event');
          onCommand?.call(cmd);
        }
      },
      onError: (error) {
        Log.w('AVSession', 'EventChannel 错误: $error');
      },
    );
  }

  AVSessionCommand? _parseCommand(String event) {
    switch (event) {
      case 'play':
        return AVSessionCommand.play;
      case 'pause':
        return AVSessionCommand.pause;
      case 'stop':
        return AVSessionCommand.stop;
      default:
        return null;
    }
  }
}
