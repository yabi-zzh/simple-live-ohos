import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:wakelock_plus_ohos/wakelock_plus_ohos.dart';
import '../../../main.dart' show isMediaKitAvailable;
import '../../services/platform_service.dart';
import '../../services/history_service.dart';
import '../../services/storage_service.dart';
import '../../models/room_models.dart';
import '../../services/danmaku_settings_service.dart';
import '../../utils/log_util.dart';

class LiveRoomController extends GetxController {
  final String roomId;
  final int platformIndex;

  LiveRoomController({required this.roomId, required this.platformIndex});

  LiveSite get site => PlatformService.instance.getSite(platformIndex);

  // 房间信息
  final detail = Rxn<LiveRoomDetail>();
  final isLoading = true.obs;
  final errorMsg = ''.obs;

  // 播放器（MediaKit 不可用时为 null）
  Player? player;
  VideoController? videoController;
  final isPlaying = false.obs;
  final isBuffering = true.obs;
  final playerAvailable = false.obs;

  // 清晰度
  final qualities = <LivePlayQuality>[].obs;
  final currentQuality = Rxn<LivePlayQuality>();
  final playUrls = <String>[].obs;
  final currentUrlIndex = 0.obs;
  final isSwitching = false.obs;

  // 弹幕
  LiveDanmaku? _danmaku;
  final danmakuMessages = <LiveMessage>[].obs;
  final chatMessages = <LiveMessage>[].obs;
  final online = 0.obs;
  final danmakuEnabled = true.obs;

  // UI 控制
  final showControls = true.obs;
  final isFullscreen = false.obs;
  Timer? _hideControlsTimer;

  // 弹幕重连
  Timer? _danmakuReconnectTimer;
  int _danmakuRetryCount = 0;
  static const int _maxDanmakuRetry = 5;
  bool _isDisposing = false;

  // Stream 订阅引用（用于 onClose 取消）
  final List<StreamSubscription> _subscriptions = [];

  @override
  void onInit() {
    super.onInit();
    _enableWakelock();

    if (isMediaKitAvailable) {
      try {
        Log.i('LiveRoom', '开始创建播放器...');
        player = Player(
          configuration: PlayerConfiguration(
            vo: null,
            logLevel: MPVLogLevel.error,
            bufferSize: 64 * 1024 * 1024, // 64MB 缓冲，适合直播流
            ready: () {
              Log.i('LiveRoom', '播放器就绪回调触发');
            },
          ),
        );
        Log.i('LiveRoom', '播放器创建成功（构造函数返回）');

        // 优化 mpv 参数：硬解 + 视频同步 + 缓存策略
        _configureMpvProperties();

        videoController = VideoController(player!);
        Log.i('LiveRoom', 'VideoController 创建成功');
        playerAvailable.value = true;

        _subscriptions.add(player!.stream.playing.listen((playing) {
          isPlaying.value = playing;
        }));
        _subscriptions.add(player!.stream.buffering.listen((buffering) {
          isBuffering.value = buffering;
        }));
        _subscriptions.add(player!.stream.error.listen((error) {
          Log.e('LiveRoom', '播放错误: $error');
          _tryNextUrl();
        }));
        Log.i('LiveRoom', '播放器事件监听已设置');
      } catch (e, stack) {
        Log.e('LiveRoom', '创建播放器失败', e, stack);
        playerAvailable.value = false;
      }
    } else {
      Log.w('LiveRoom', 'MediaKit 不可用，播放功能已禁用');
    }

    _loadRoom();
  }

  @override
  void onClose() {
    _isDisposing = true;
    _hideControlsTimer?.cancel();
    _danmakuReconnectTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _danmaku?.stop();
    player?.dispose();
    _disableWakelock();
    // 确保退出时恢复竖屏
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.onClose();
  }

  void _configureMpvProperties() {
    if (player == null) return;
    try {
      final nativePlayer = player!.platform;
      if (nativePlayer is NativePlayer) {
        // 硬件解码：优先使用硬解，失败自动回退软解
        nativePlayer.setProperty('hwdec', 'auto-safe');
        // 视频同步：适合直播的低延迟同步
        nativePlayer.setProperty('video-sync', 'audio');
        // 直播流缓存策略
        nativePlayer.setProperty('cache', 'yes');
        nativePlayer.setProperty('cache-secs', '5');
        // 降低直播延迟
        nativePlayer.setProperty('demuxer-lavf-o', 'fflags=+nobuffer');
        Log.i('LiveRoom', 'mpv 参数配置完成');
      }
    } catch (e) {
      Log.w('LiveRoom', 'mpv 参数配置失败: $e');
    }
  }

  void _enableWakelock() {
    try {
      WakelockPlusOhos.toggle(enable: true);
      Log.d('LiveRoom', '屏幕常亮已开启');
    } catch (e) {
      Log.w('LiveRoom', '开启屏幕常亮失败: $e');
    }
  }

  void _disableWakelock() {
    try {
      WakelockPlusOhos.toggle(enable: false);
      Log.d('LiveRoom', '屏幕常亮已关闭');
    } catch (e) {
      Log.w('LiveRoom', '关闭屏幕常亮失败: $e');
    }
  }

  Future<void> _loadRoom() async {
    isLoading.value = true;
    errorMsg.value = '';
    try {
      final roomDetail = await site.getRoomDetail(roomId: roomId);
      detail.value = roomDetail;

      // 添加观看历史
      _addHistory(roomDetail);

      if (!roomDetail.status) {
        errorMsg.value = '主播未开播';
        isLoading.value = false;
        return;
      }

      // 并行加载清晰度和启动弹幕
      await Future.wait([
        _loadQualities(roomDetail),
        _startDanmaku(roomDetail),
      ]);
    } catch (e, stack) {
      Log.e('LiveRoom', '加载房间失败', e, stack);
      errorMsg.value = '加载失败: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void _addHistory(LiveRoomDetail roomDetail) {
    try {
      HistoryService.instance.addHistory(HistoryRoom(
        roomId: roomId,
        platformIndex: platformIndex,
        title: roomDetail.title,
        userName: roomDetail.userName,
        cover: roomDetail.cover,
        watchTime: DateTime.now(),
      ));
    } catch (e) {
      Log.w('LiveRoom', '添加历史失败: $e');
    }
  }

  Future<void> _loadQualities(LiveRoomDetail roomDetail) async {
    try {
      final list = await site.getPlayQualites(detail: roomDetail);
      qualities.assignAll(list);
      if (list.isNotEmpty && playerAvailable.value) {
        final preferred = _pickPreferredQuality(list);
        await switchQuality(preferred);
      }
    } catch (e, stack) {
      Log.e('LiveRoom', '加载清晰度失败', e, stack);
    }
  }

  /// 根据用户偏好选择清晰度
  /// 0=最高, 1=较高, 2=中等, 3=最低
  LivePlayQuality _pickPreferredQuality(List<LivePlayQuality> list) {
    final pref = StorageService.instance.getValue<int>('preferred_quality', 0);
    if (list.length <= 1) return list.first;
    switch (pref) {
      case 1: // 较高 - 第二个
        return list.length > 1 ? list[1] : list.first;
      case 2: // 中等 - 中间
        return list[list.length ~/ 2];
      case 3: // 最低 - 最后一个
        return list.last;
      default: // 最高 - 第一个
        return list.first;
    }
  }

  Future<void> switchQuality(LivePlayQuality quality) async {
    if (!playerAvailable.value) {
      Log.w('LiveRoom', '播放器不可用，无法切换清晰度');
      return;
    }
    isSwitching.value = true;
    currentQuality.value = quality;
    try {
      final urls = await site.getPlayUrls(
        detail: detail.value!,
        quality: quality,
      );
      playUrls.assignAll(urls.urls);
      currentUrlIndex.value = 0;
      if (urls.urls.isNotEmpty) {
        _playUrl(urls.urls.first, urls.headers);
      }
    } catch (e, stack) {
      Log.e('LiveRoom', '获取播放地址失败', e, stack);
    } finally {
      isSwitching.value = false;
    }
  }

  void _playUrl(String url, Map<String, String>? headers) {
    if (!playerAvailable.value || player == null) {
      Log.w('LiveRoom', '播放器不可用，无法播放');
      return;
    }
    Log.d('LiveRoom', '播放: $url');
    Log.d('LiveRoom', '请求头: $headers');
    try {
      player!.open(
        Media(url, httpHeaders: headers ?? {}),
      );
      Log.i('LiveRoom', 'player.open() 调用成功');
      // 开始播放后启动控制层自动隐藏
      resetHideTimer();
    } catch (e, stack) {
      Log.e('LiveRoom', 'player.open() 调用失败', e, stack);
    }
  }

  void _tryNextUrl() {
    if (!playerAvailable.value) return;
    final nextIndex = currentUrlIndex.value + 1;
    if (nextIndex < playUrls.length) {
      currentUrlIndex.value = nextIndex;
      Log.i('LiveRoom', '切换线路 ${nextIndex + 1}/${playUrls.length}');
      Get.snackbar(
        '自动切换线路',
        '正在尝试线路 ${nextIndex + 1}/${playUrls.length}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(12),
      );
      _playUrl(playUrls[nextIndex], null);
    } else {
      Log.w('LiveRoom', '所有线路均失败');
      Get.snackbar(
        '播放失败',
        '所有线路均无法播放',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(12),
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> _startDanmaku(LiveRoomDetail roomDetail) async {
    _danmaku = site.getDanmaku();
    _danmaku!.onMessage = _onDanmakuMessage;
    _danmaku!.onClose = (msg) {
      Log.i('LiveRoom', '弹幕连接关闭: $msg');
      _scheduleDanmakuReconnect();
    };
    _danmaku!.onReady = () {
      Log.i('LiveRoom', '弹幕连接就绪');
      _danmakuRetryCount = 0;
    };
    try {
      await _danmaku!.start(roomDetail.danmakuData);
    } catch (e, stack) {
      Log.e('LiveRoom', '弹幕连接失败', e, stack);
      _scheduleDanmakuReconnect();
    }
  }

  void _scheduleDanmakuReconnect() {
    if (_isDisposing) return;
    if (_danmakuRetryCount >= _maxDanmakuRetry) {
      Log.w('LiveRoom', '弹幕重连已达上限 ($_maxDanmakuRetry 次)');
      return;
    }
    // 指数退避: 2s, 4s, 8s, 16s, 32s
    final delay = Duration(seconds: 2 << _danmakuRetryCount);
    _danmakuRetryCount++;
    Log.i('LiveRoom', '弹幕将在 ${delay.inSeconds}s 后重连 (第$_danmakuRetryCount次)');
    _danmakuReconnectTimer?.cancel();
    _danmakuReconnectTimer = Timer(delay, _reconnectDanmaku);
  }

  Future<void> _reconnectDanmaku() async {
    if (_isDisposing) return;
    final roomDetail = detail.value;
    if (roomDetail == null || !roomDetail.status) return;
    try {
      _danmaku?.stop();
      await _startDanmaku(roomDetail);
    } catch (e, stack) {
      Log.e('LiveRoom', '弹幕重连失败', e, stack);
    }
  }

  /// 添加系统消息
  void addSysMsg(String msg) {
    chatMessages.add(
      LiveMessage(
        type: LiveMessageType.chat,
        userName: "LiveSysMessage",
        message: msg,
        color: LiveMessageColor.white,
      ),
    );
  }

  void _onDanmakuMessage(LiveMessage msg) {
    if (msg.type == LiveMessageType.online) {
      online.value = msg.data is int ? msg.data : 0;
      return;
    }
    if (msg.type == LiveMessageType.chat || msg.type == LiveMessageType.superChat) {
      // 弹幕屏蔽词过滤
      if (DanmakuSettingsService.instance.shouldFilter(msg.message)) return;

      chatMessages.add(msg);
      // 保留最近200条聊天
      if (chatMessages.length > 200) {
        chatMessages.removeRange(0, chatMessages.length - 200);
      }
      if (danmakuEnabled.value) {
        danmakuMessages.add(msg);
        // 保留最近100条弹幕渲染消息
        if (danmakuMessages.length > 100) {
          danmakuMessages.removeRange(0, danmakuMessages.length - 100);
        }
      }
    }
  }

  void toggleDanmaku() {
    danmakuEnabled.toggle();
  }

  void toggleControls() {
    showControls.toggle();
    resetHideTimer();
  }

  void resetHideTimer() {
    _hideControlsTimer?.cancel();
    if (showControls.value) {
      _hideControlsTimer = Timer(const Duration(seconds: 5), () {
        showControls.value = false;
      });
    }
  }

  void togglePlay() {
    player?.playOrPause();
  }

  Future<void> toggleFullscreen() async {
    isFullscreen.toggle();
    if (isFullscreen.value) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    resetHideTimer();
  }

  Future<void> retry() async {
    await _loadRoom();
  }

  /// 刷新当前流（不重新加载房间详情，只重新拉取播放地址）
  final isRefreshingStream = false.obs;

  Future<void> refreshStream() async {
    if (!playerAvailable.value || isRefreshingStream.value) return;
    final quality = currentQuality.value;
    if (quality == null) return;
    isRefreshingStream.value = true;
    try {
      await switchQuality(quality);
      Log.i('LiveRoom', '刷新流成功');
    } catch (e, stack) {
      Log.e('LiveRoom', '刷新流失败', e, stack);
    } finally {
      isRefreshingStream.value = false;
    }
  }

  /// 切换线路
  void switchLine(int index) {
    if (index >= 0 && index < playUrls.length) {
      currentUrlIndex.value = index;
      _playUrl(playUrls[index], null);
    }
  }
}
