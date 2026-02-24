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
import '../../services/avsession_service.dart';
import '../../utils/log_util.dart';
import '../../utils/responsive.dart';

class LiveRoomController extends GetxController with WidgetsBindingObserver {
  final String roomId;
  final int platformIndex;

  LiveRoomController({required this.roomId, required this.platformIndex});

  // 原生生命周期通道（绕过 WidgetsBindingObserver，直接从 EntryAbility 接收）
  static const _lifecycleChannel = MethodChannel('com.simplelive/lifecycle');

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
  final hasVideoFrame = false.obs;

  // 清晰度
  final qualities = <LivePlayQuality>[].obs;
  final currentQuality = Rxn<LivePlayQuality>();
  final playUrls = <String>[].obs;
  final currentUrlIndex = 0.obs;
  final isSwitching = false.obs;
  Map<String, String>? _currentHeaders;

  // 弹幕
  LiveDanmaku? _danmaku;
  final chatMessages = <LiveMessage>[].obs;
  /// 弹幕渲染回调（由 Page 注册，绕过 RxList 通知机制，避免消息丢失/重复）
  void Function(LiveMessage msg)? onDanmakuRender;
  final online = 0.obs;
  final danmakuEnabled = true.obs;

  // UI 控制
  final showControls = true.obs;
  final isFullscreen = false.obs;
  Timer? _hideControlsTimer;

  // 定时关闭
  Timer? _autoExitTimer;

  // 弹幕重连
  Timer? _danmakuReconnectTimer;
  int _danmakuRetryCount = 0;
  static const int _maxDanmakuRetry = 5;
  bool _isDisposing = false;

  // AVSession 状态：播放器首次播放前不同步 PAUSE，避免 PAUSE->PLAY 快速翻转
  bool _hasEverPlayed = false;

  // 后台状态
  bool _isInBackground = false;
  bool _wasPlayingBeforeBackground = false;
  int _bgResumeRetryCount = 0;
  static const int _maxBgResumeRetry = 3;
  DateTime? _backgroundEntryTime;
  static const int _bgRefreshThresholdSeconds = 5;
  bool _isRecoveringVideo = false;

  // Stream 订阅引用（用于 onClose 取消）
  final List<StreamSubscription> _subscriptions = [];

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleChannel.setMethodCallHandler(_handleNativeLifecycle);
    _enableWakelock();

    if (isMediaKitAvailable) {
      try {
        Log.i('LiveRoom', '开始创建播放器...');
        final bufferMB = StorageService.instance.getValue<int>('buffer_size', 32);
        player = Player(
          configuration: PlayerConfiguration(
            vo: null,
            logLevel: MPVLogLevel.error,
            bufferSize: bufferMB * 1024 * 1024,
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
        // 监听首帧渲染：rect 从 null 变为有效尺寸时表示视频已出画面
        void onRect() {
          final r = videoController!.rect.value;
          if (r != null && r.width > 0 && r.height > 0) {
            hasVideoFrame.value = true;
          }
        }
        videoController!.rect.addListener(onRect);
        playerAvailable.value = true;

        _subscriptions.add(player!.stream.playing.listen((playing) {
          isPlaying.value = playing;
          // 暂停模式下不尝试后台恢复
          if (_isInBackground && !playing && _wasPlayingBeforeBackground && _bgPlayMode != 2) {
            if (_bgResumeRetryCount < _maxBgResumeRetry) {
              _bgResumeRetryCount++;
              Log.i('LiveRoom', '后台播放被暂停，尝试恢复($_bgResumeRetryCount/$_maxBgResumeRetry)...');
              Future.delayed(const Duration(milliseconds: 500), () {
                if (!_isDisposing && _isInBackground && player != null && !isPlaying.value) {
                  player!.play();
                }
              });
            } else {
              Log.w('LiveRoom', '后台恢复播放已达上限，同步 PAUSE');
              _syncPlaybackState(false);
            }
            return;
          }
          _syncPlaybackState(playing);
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
    onDanmakuRender = null;
    _lifecycleChannel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _autoExitTimer?.cancel();
    _danmakuReconnectTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _danmaku?.stop();
    player?.dispose();
    _disableWakelock();
    AVSessionService.instance.deactivate();
    // 确保退出时恢复方向设置（平板允许自由旋转，手机锁定竖屏）
    SystemChrome.setPreferredOrientations(
      Responsive.isTabletDevice ? DeviceOrientation.values : [DeviceOrientation.portraitUp],
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.onClose();
  }

  void _configureMpvProperties() {
    if (player == null) return;
    try {
      final nativePlayer = player!.platform;
      if (nativePlayer is NativePlayer) {
        final hwDecode = StorageService.instance.getValue<bool>('hardware_decode', true);
        nativePlayer.setProperty('hwdec', hwDecode ? 'auto-safe' : 'no');
        nativePlayer.setProperty('video-sync', 'audio');
        nativePlayer.setProperty('cache', 'yes');
        nativePlayer.setProperty('cache-secs', '2');
        nativePlayer.setProperty('demuxer-lavf-o',
            'fflags=+nobuffer,probesize=32768,analyzeduration=500000');
        final bufferMB = StorageService.instance.getValue<int>('buffer_size', 32);
        Log.i('LiveRoom', 'mpv: hwdec=$hwDecode, buffer=${bufferMB}MB');
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

      if (!roomDetail.status) {
        // 未开播也记录历史
        Future.microtask(() => _addHistory(roomDetail));
        errorMsg.value = '主播未开播';
        isLoading.value = false;
        return;
      }

      // AVSession 只依赖 roomDetail，提前激活让系统播控中心更早可用
      _activateAVSession(roomDetail);

      // 历史记录写入不阻塞关键路径
      Future.microtask(() => _addHistory(roomDetail));

      // 并行加载清晰度和启动弹幕
      await Future.wait([
        _loadQualities(roomDetail),
        _startDanmaku(roomDetail),
      ]);

      // 自动全屏
      if (StorageService.instance.getValue<bool>('auto_fullscreen', false)) {
        Future.microtask(() => toggleFullscreen());
      }

      // 定时关闭
      _startAutoExitTimer();
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
      _currentHeaders = urls.headers;
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
    hasVideoFrame.value = false;
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
    if (!playerAvailable.value || playUrls.isEmpty) return;
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
      _playUrl(playUrls[nextIndex], _currentHeaders);
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
      // 累积到 250 条再截断到 200，减少 removeRange 触发频率
      if (chatMessages.length > 250) {
        chatMessages.removeRange(0, chatMessages.length - 200);
      }
      if (danmakuEnabled.value) {
        onDanmakuRender?.call(msg);
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
      // 平板允许自由旋转，手机锁定竖屏
      await SystemChrome.setPreferredOrientations(
        Responsive.isTabletDevice ? DeviceOrientation.values : [DeviceOrientation.portraitUp],
      );
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    resetHideTimer();
  }

  Future<void> retry() async {
    await _loadRoom();
  }

  void _startAutoExitTimer() {
    _autoExitTimer?.cancel();
    final minutes = StorageService.instance.getValue<int>('auto_exit_minutes', 0);
    if (minutes <= 0) return;
    _autoExitTimer = Timer(Duration(minutes: minutes), () {
      Log.i('LiveRoom', '定时关闭触发 ($minutes 分钟)');
      Get.back();
    });
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
      _playUrl(playUrls[index], _currentHeaders);
    }
  }

  // ==================== AVSession 后台播控 ====================

  /// 原生生命周期通道处理（主要机制）
  Future<dynamic> _handleNativeLifecycle(MethodCall call) async {
    switch (call.method) {
      case 'onBackground':
        _onEnterBackground();
        break;
      case 'onForeground':
        _onEnterForeground();
        break;
    }
    return null;
  }

  /// Flutter 生命周期回调（备用机制）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _onEnterBackground();
    } else if (state == AppLifecycleState.resumed) {
      _onEnterForeground();
    }
  }

  /// 后台播放模式：0=继续播放, 1=静音保持连接, 2=暂停
  int get _bgPlayMode => StorageService.instance.getValue<int>('bg_play_mode', 1);

  void _onEnterBackground() {
    if (_isInBackground) return;
    _isInBackground = true;
    _backgroundEntryTime = DateTime.now();
    _wasPlayingBeforeBackground = isPlaying.value;
    _bgResumeRetryCount = 0;
    final mode = _bgPlayMode;
    Log.i('LiveRoom', '进入后台, wasPlaying=$_wasPlayingBeforeBackground, mode=$mode');
    switch (mode) {
      case 0: break; // 继续播放，不做任何处理
      case 2: player?.pause(); break; // 暂停
      default: _setMute(true); break; // 静音保持连接
    }
  }

  void _onEnterForeground() {
    if (!_isInBackground) return;
    _isInBackground = false;
    _bgResumeRetryCount = 0;
    final mode = _bgPlayMode;
    if (mode == 1) _setMute(false);
    final bgDuration = _backgroundEntryTime != null
        ? DateTime.now().difference(_backgroundEntryTime!)
        : Duration.zero;
    final stillPlaying = isPlaying.value;
    Log.i('LiveRoom', '回到前台, 后台时长=${bgDuration.inSeconds}s, 流存活=$stillPlaying');

    if (!_wasPlayingBeforeBackground || !playerAvailable.value) return;

    if (mode == 2) {
      // 暂停模式：恢复播放或重连
      if (bgDuration.inSeconds >= _bgRefreshThresholdSeconds) {
        _reconnectStream();
      } else {
        player?.play();
      }
    } else if (stillPlaying) {
      _recoverVideoOnly();
    } else if (bgDuration.inSeconds >= _bgRefreshThresholdSeconds) {
      _reconnectStream();
    }
  }

  /// 设置播放器静音/取消静音
  void _setMute(bool mute) {
    if (player == null) return;
    try {
      final nativePlayer = player!.platform;
      if (nativePlayer is NativePlayer) {
        nativePlayer.setProperty('mute', mute ? 'yes' : 'no');
        Log.d('LiveRoom', '静音状态: $mute');
      }
    } catch (e) {
      Log.w('LiveRoom', '设置静音失败: $e');
    }
  }

  /// 流连接存活时的快速恢复：仅刷新视频输出管线。
  ///
  /// 音频仍在播放说明 mpv 的 demuxer/网络层正常工作，
  /// 只是 GPU 渲染上下文可能被系统回收。
  /// 通过 vid=no → vid=auto 强制 mpv 重建 VO，不重连网络流。
  Future<void> _recoverVideoOnly() async {
    if (_isRecoveringVideo) return;
    _isRecoveringVideo = true;
    try {
      if (_isDisposing || player == null) return;
      final nativePlayer = player!.platform;
      if (nativePlayer is NativePlayer) {
        Log.i('LiveRoom', '快速路径: 流存活，刷新 VO (vid=no/auto)');
        nativePlayer.setProperty('vid', 'no');
        await Future.delayed(const Duration(milliseconds: 16));
        if (_isDisposing || _isInBackground) return;
        nativePlayer.setProperty('vid', 'auto');
        Log.i('LiveRoom', 'VO 刷新完成');
      }
    } finally {
      _isRecoveringVideo = false;
    }
  }

  /// 流已断开时的重连：直接重新打开当前流地址。
  Future<void> _reconnectStream() async {
    if (_isRecoveringVideo) return;
    _isRecoveringVideo = true;
    try {
      // 等待 Flutter Surface 重建
      await Future.delayed(const Duration(milliseconds: 300));
      if (_isDisposing || _isInBackground || !playerAvailable.value) return;

      if (playUrls.isNotEmpty) {
        Log.i('LiveRoom', '流已断开，直接重连当前线路');
        _playUrl(playUrls[currentUrlIndex.value], _currentHeaders);
      }
    } finally {
      _isRecoveringVideo = false;
    }
  }

  void _activateAVSession(LiveRoomDetail roomDetail) {
    final siteName = site.name;
    AVSessionService.instance.activate(
      title: roomDetail.title,
      artist: '${roomDetail.userName} ($siteName)',
      mediaImage: roomDetail.cover,
      assetId: roomDetail.roomId,
    );
    AVSessionService.instance.onCommand = _onAVSessionCommand;
  }

  void _onAVSessionCommand(AVSessionCommand command) {
    switch (command) {
      case AVSessionCommand.play:
        if (player != null && !isPlaying.value) {
          player!.play();
        }
        break;
      case AVSessionCommand.pause:
        if (player != null && isPlaying.value) {
          player!.pause();
        }
        break;
      case AVSessionCommand.stop:
        player?.pause();
        break;
    }
  }

  void _syncPlaybackState(bool playing) {
    // 播放器首次播放前忽略 PAUSE 事件，避免 activate 后立即 PAUSE->PLAY 翻转
    if (!_hasEverPlayed) {
      if (!playing) return;
      _hasEverPlayed = true;
    }
    AVSessionService.instance.updatePlaybackState(playing ? 0 : 1);
  }
}
