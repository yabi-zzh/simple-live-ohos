import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'live_room_controller.dart';
import '../../services/favorite_service.dart';
import '../../services/danmaku_settings_service.dart';
import '../../models/room_models.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/net_image.dart';
import '../../utils/responsive.dart';

class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({super.key});

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  late LiveRoomController _controller;
  DanmakuController? _danmakuController;
  Worker? _danmakuSettingsWorker;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>;
    _controller = Get.put(LiveRoomController(
      roomId: args['roomId'] as String,
      platformIndex: args['platformIndex'] as int,
    ));

    // 注册弹幕渲染回调（直接回调，避免 ever + RxList 的消息丢失/重复问题）
    _controller.onDanmakuRender = (msg) {
      if (_danmakuController != null) {
        _danmakuController!.addDanmaku(DanmakuContentItem(
          msg.message,
          color: Color.fromARGB(255, msg.color.r, msg.color.g, msg.color.b),
        ));
      }
    };

    // 监听弹幕设置变化，实时更新渲染参数（不重建 DanmakuScreen）
    _danmakuSettingsWorker = ever(
      DanmakuSettingsService.instance.settings,
      (s) {
        _danmakuController?.updateOption(DanmakuOption(
          fontSize: s.fontSize,
          area: s.area,
          duration: s.duration,
          opacity: s.opacity,
        ));
      },
    );
  }

  @override
  void dispose() {
    _controller.onDanmakuRender = null;
    _danmakuSettingsWorker?.dispose();
    super.dispose();
  }

  void _toggleFavorite(LiveRoomDetail detail) {
    final service = FavoriteService.instance;
    final roomId = _controller.roomId;
    final platformIndex = _controller.platformIndex;
    if (service.isFavorite(roomId, platformIndex)) {
      service.removeFavorite(roomId, platformIndex);
    } else {
      service.addFavorite(FavoriteRoom(
        roomId: roomId,
        platformIndex: platformIndex,
        title: detail.title,
        userName: detail.userName,
        cover: detail.cover,
        addTime: DateTime.now(),
      ));
    }
  }

  /// 是否显示 AppBar（全屏时隐藏，其余情况都显示）
  bool _shouldShowAppBar(bool isFullscreen) {
    return !isFullscreen;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isFullscreen = _controller.isFullscreen.value;
      return PopScope(
        canPop: !isFullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && isFullscreen) {
            _controller.toggleFullscreen();
          }
        },
        child: Scaffold(
        appBar: _shouldShowAppBar(isFullscreen)
            ? AppBar(
                toolbarHeight: 48,
                titleSpacing: 0,
                title: Obx(() {
                  final detail = _controller.detail.value;
                  return Text(
                    detail?.title ?? '直播间',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  );
                }),
              )
            : null,
        body: _buildBody(isFullscreen),
        ),
      );
    });
  }

  Widget _buildBody(bool isFullscreen) {
    return Obx(() {
      if (_controller.isLoading.value) {
        return const LoadingView(text: '加载直播间...');
      }
      if (_controller.errorMsg.value.isNotEmpty) {
        final detail = _controller.detail.value;
        if (_controller.errorMsg.value == '主播未开播' && detail != null) {
          return _buildNotLiveView(detail);
        }
        return ErrorView(
          text: _controller.errorMsg.value,
          onRetry: _controller.retry,
        );
      }
      if (isFullscreen) {
        return _buildPlayerArea();
      }

      // 宽屏非全屏：左右分栏（播放器+信息 | 弹幕列表）
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= Responsive.expandedBreakpoint) {
            return Row(
              children: [
                // 左侧：播放器 + 房间信息
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildPlayerArea(),
                      _buildRoomInfoBar(),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                // 右侧：弹幕/聊天列表
                Expanded(
                  flex: 2,
                  child: _buildChatList(),
                ),
              ],
            );
          }
          // 窄屏：上下结构
          return Column(
            children: [
              _buildPlayerArea(),
              _buildRoomInfoBar(),
              Expanded(child: _buildChatList()),
            ],
          );
        },
      );
    });
  }

  Widget _buildNotLiveView(LiveRoomDetail detail) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 封面图
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetImage(detail.cover, fit: BoxFit.cover),
                Container(color: Colors.black.withOpacity(0.5)),
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_off, color: Colors.white70, size: 48),
                      SizedBox(height: 8),
                      Text(
                        '主播未开播',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 房间信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (detail.userAvatar.isNotEmpty)
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(detail.userAvatar),
                      ),
                    if (detail.userAvatar.isNotEmpty) const SizedBox(width: 8),
                    Text(
                      detail.userName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _controller.retry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('刷新'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerArea() {
    final playerContent = Obx(() {
      if (!_controller.playerAvailable.value) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.white70, size: 48),
                SizedBox(height: 12),
                Text(
                  '播放器不可用',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  'MediaKit 原生库未加载',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }

      return Stack(
        children: [
          // 播放器 + 手势层（填满整个区域）
          Positioned.fill(
            child: GestureDetector(
              onTap: _controller.toggleControls,
              child: Container(
                color: Colors.black,
                child: Video(
                  controller: _controller.videoController!,
                  controls: null,
                ),
              ),
            ),
          ),
          // 封面占位层：首帧渲染前显示封面图，出画面后淡出
          Obx(() {
            final cover = _controller.detail.value?.cover;
            final playing = _controller.isPlaying.value;
            if (cover == null || cover.isEmpty) return const SizedBox.shrink();
            return AnimatedOpacity(
              opacity: playing ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: playing,
                child: GestureDetector(
                  onTap: _controller.toggleControls,
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: NetImage(cover, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            );
          }),
          // 弹幕层（只创建一次，通过 updateOption 实时更新配置）
          Positioned(
            top: _controller.isFullscreen.value
                ? MediaQuery.of(context).viewPadding.top + 40
                : 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Obx(() => Visibility(
                    visible: _controller.danmakuEnabled.value,
                    maintainState: true,
                    child: DanmakuScreen(
                      createdController: (c) => _danmakuController = c,
                      option: DanmakuOption(
                        fontSize: DanmakuSettingsService.instance.settings.value.fontSize,
                        area: DanmakuSettingsService.instance.settings.value.area,
                        duration: DanmakuSettingsService.instance.settings.value.duration,
                        opacity: DanmakuSettingsService.instance.settings.value.opacity,
                      ),
                    ),
                  )),
            ),
          ),
          // 缓冲/切换指示器
          Obx(() {
            final switching = _controller.isSwitching.value;
            final buffering = _controller.isBuffering.value;
            final playing = _controller.isPlaying.value;
            // 播放器已在播放时，不显示缓冲转圈（mpv 的 buffering 事件与首帧渲染不严格同步）
            if (!switching && (!buffering || playing)) return const SizedBox.shrink();
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                  if (switching)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '切换中...',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                ],
              ),
            );
          }),
          // 播放控制覆盖层
          if (_controller.isFullscreen.value)
            // 全屏：点击显示/隐藏完整覆盖层
            Positioned.fill(
              child: Obx(() => AnimatedOpacity(
                    opacity: _controller.showControls.value ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_controller.showControls.value,
                      child: _buildFullscreenOverlay(),
                    ),
                  )),
            )
          else
            // 竖屏：底部极简控制条，几秒后自动隐藏
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Obx(() => AnimatedOpacity(
                    opacity: _controller.showControls.value ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_controller.showControls.value,
                      child: _buildPortraitOverlay(),
                    ),
                  )),
            ),
        ],
      );
    });

    if (_controller.isFullscreen.value) {
      return SizedBox.expand(child: playerContent);
    }
    return AspectRatio(aspectRatio: 16 / 9, child: playerContent);
  }

  /// 竖屏极简覆盖层：底部渐变条
  Widget _buildPortraitOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black54],
        ),
      ),
      child: Row(
        children: [
          // 播放/暂停
          Obx(() => IconButton(
                icon: Icon(
                  _controller.isPlaying.value
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _controller.togglePlay,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              )),
          // 弹幕开关
          Obx(() => IconButton(
                icon: Icon(
                  _controller.danmakuEnabled.value
                      ? Icons.subtitles
                      : Icons.subtitles_off,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _controller.toggleDanmaku,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              )),
          // 弹幕设置
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white, size: 20),
            onPressed: () => _showDanmakuSettingsPanel(context),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
          // 刷新
          Obx(() => IconButton(
                icon: _controller.isRefreshingStream.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.refresh, color: Colors.white, size: 20),
                onPressed: _controller.isRefreshingStream.value
                    ? null
                    : _controller.refreshStream,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              )),
          const Spacer(),
          // 全屏按钮
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
            onPressed: _controller.toggleFullscreen,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  /// 全屏完整覆盖层：顶部栏 + 底部栏
  Widget _buildFullscreenOverlay() {
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;

    return Column(
      children: [
        // 顶部信息栏
        Container(
          padding: EdgeInsets.fromLTRB(12, statusBarHeight + 8, 12, 12),
          decoration: const BoxDecoration(
            color: Color(0xCC000000),
          ),
          child: Obx(() {
            final detail = _controller.detail.value;
            return Row(
              children: [
                // 退出全屏
                GestureDetector(
                  onTap: _controller.toggleFullscreen,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          detail?.title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // 录播标签
                      if (detail?.isRecord == true)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '录播',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 开播时长
                if (_formatShowTime(detail?.showTime).isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 11,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatShowTime(detail?.showTime),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                // 在线人数
                if (_controller.online.value > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.remove_red_eye,
                          size: 13,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatOnline(_controller.online.value),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                // 清晰度按钮
                Obx(() {
                  if (_controller.qualities.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    onTap: () => _showQualityPanel(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _controller.currentQuality.value?.quality ?? '清晰度',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 6),
                // 线路按钮
                Obx(() {
                  if (_controller.playUrls.length <= 1) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    onTap: () => _showLinePanel(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '线路${_controller.currentUrlIndex.value + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ),
        const Spacer(),
        // 底部控制按钮
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          decoration: const BoxDecoration(
            color: Color(0xCC000000),
          ),
          child: Row(
            children: [
              // 播放/暂停
              Obx(() => IconButton(
                    icon: Icon(
                      _controller.isPlaying.value
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: _controller.togglePlay,
                  )),
              // 刷新流
              Obx(() => IconButton(
                    icon: _controller.isRefreshingStream.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.refresh, color: Colors.white, size: 22),
                    onPressed: _controller.isRefreshingStream.value
                        ? null
                        : _controller.refreshStream,
                  )),
              // 弹幕开关
              Obx(() => IconButton(
                    icon: Icon(
                      _controller.danmakuEnabled.value
                          ? Icons.subtitles
                          : Icons.subtitles_off,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: _controller.toggleDanmaku,
                  )),
              // 弹幕设置
              IconButton(
                icon: const Icon(
                  Icons.tune,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () => _showDanmakuSettingsPanel(context),
              ),
              const Spacer(),
              // 退出全屏
              IconButton(
                icon: const Icon(
                  Icons.fullscreen_exit,
                  color: Colors.white,
                ),
                onPressed: _controller.toggleFullscreen,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoomInfoBar() {
    return Obx(() {
      final detail = _controller.detail.value;
      if (detail == null) return const SizedBox.shrink();

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 主信息行
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                // 主播头像
                CircleAvatar(
                  radius: 18,
                  backgroundImage: detail.userAvatar.isNotEmpty
                      ? NetworkImage(detail.userAvatar)
                      : null,
                  child: detail.userAvatar.isEmpty
                      ? const Icon(Icons.person, size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                // 主播名 + 房间标题
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              detail.userName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 录播标签
                          if (detail.isRecord)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '录播',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 开播时长
                if (_formatShowTime(detail.showTime).isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatShowTime(detail.showTime),
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                // 在线人数
                if (_controller.online.value > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.remove_red_eye,
                          size: 12,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatOnline(_controller.online.value),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                // 关注按钮
            Obx(() {
              final isFav = FavoriteService.instance.isFavorite(
                _controller.roomId,
                _controller.platformIndex,
              );
              return FilledButton.icon(
                onPressed: () => _toggleFavorite(detail),
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                ),
                label: Text(isFav ? '已关注' : '关注'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              );
            }),
          ],
        ),
      ),
      // 公告/简介
      if (_hasNoticeOrIntro(detail))
        _buildNoticeBar(detail),
      ],
      );
    });
  }

  bool _hasNoticeOrIntro(LiveRoomDetail detail) {
    return (detail.notice != null && _stripHtml(detail.notice!).isNotEmpty) ||
        (detail.introduction != null && _stripHtml(detail.introduction!).isNotEmpty);
  }

  Widget _buildNoticeBar(LiveRoomDetail detail) {
    final String text;
    final String label;
    if (detail.notice != null && _stripHtml(detail.notice!).isNotEmpty) {
      text = _stripHtml(detail.notice!);
      label = '公告';
    } else {
      text = _stripHtml(detail.introduction!);
      label = '简介';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return Obx(() {
      if (_controller.chatMessages.isEmpty) {
        return const Center(
          child: Text('暂无弹幕', style: TextStyle(color: Colors.grey)),
        );
      }
      return ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _controller.chatMessages.length,
        itemBuilder: (context, index) {
          final msg = _controller.chatMessages[_controller.chatMessages.length - 1 - index];
          return _buildChatItem(msg);
        },
      );
    });
  }

  Widget _buildChatItem(LiveMessage msg) {
    // 系统消息特殊处理
    if (msg.userName == "LiveSysMessage") {
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                msg.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      );
    }

    final isSuperChat = msg.type == LiveMessageType.superChat;

    // SuperChat 完整渲染
    if (isSuperChat && msg.data is LiveSuperChatMessage) {
      final sc = msg.data as LiveSuperChatMessage;
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _parseSCColor(sc.backgroundColor, Colors.orange),
                    _parseSCColor(sc.backgroundBottomColor, Colors.deepOrange),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sc.face.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        sc.face,
                        width: 32,
                        height: 32,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 32, height: 32),
                      ),
                    ),
                  if (sc.face.isNotEmpty) const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              sc.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '¥${sc.price}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sc.message,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // 普通消息
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
                children: [
                  TextSpan(
                    text: '${msg.userName}: ',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: msg.message,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatOnline(int count) {
    if (count <= 0) return '';
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万人';
    }
    return '$count人';
  }

  /// 去除 HTML 标签并清理空白
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  /// 将 Unix 时间戳转为开播时长（如 "2小时30分"）
  String _formatShowTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final ts = int.tryParse(raw);
    if (ts == null) return raw; // 非时间戳则原样返回
    final start = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final diff = DateTime.now().difference(start);
    if (diff.isNegative) return '';
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) return '$hours小时${minutes}分';
    return '$minutes分钟';
  }

  void _showQualityPanel(BuildContext context) {
    _controller.resetHideTimer();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: Responsive.maxSheetWidth),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.6,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('选择清晰度',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                ...List.generate(_controller.qualities.length, (i) {
                  final q = _controller.qualities[i];
                  final isSelected =
                      _controller.currentQuality.value?.quality == q.quality;
                  return ListTile(
                    title: Text(q.quality),
                    trailing: isSelected
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    selected: isSelected,
                    onTap: () {
                      Navigator.pop(ctx);
                      _controller.switchQuality(q);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLinePanel(BuildContext context) {
    _controller.resetHideTimer();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: Responsive.maxSheetWidth),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.6,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('选择线路',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                ...List.generate(_controller.playUrls.length, (i) {
                  final isSelected = _controller.currentUrlIndex.value == i;
                  return ListTile(
                    title: Text('线路${i + 1}'),
                    trailing: isSelected
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    selected: isSelected,
                    onTap: () {
                      Navigator.pop(ctx);
                      _controller.switchLine(i);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDanmakuSettingsPanel(BuildContext context) {
    _controller.resetHideTimer();
    final service = DanmakuSettingsService.instance;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: Responsive.maxSheetWidth),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Obx(() {
              final s = service.settings.value;
              return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('弹幕设置',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.block, size: 18),
                      label: Text('屏蔽词 (${s.shieldWords.length})'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showShieldWordsDialog(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSettingsSlider(
                  context,
                  '字体大小',
                  '${s.fontSize.round()}',
                  s.fontSize,
                  10,
                  30,
                  service.updateFontSize,
                ),
                _buildSettingsSlider(
                  context,
                  '弹幕透明度',
                  '${(s.opacity * 100).round()}%',
                  s.opacity,
                  0.1,
                  1.0,
                  service.updateOpacity,
                ),
                _buildSettingsSlider(
                  context,
                  '弹幕速度',
                  '${s.duration.round()}秒',
                  s.duration,
                  3,
                  15,
                  service.updateDuration,
                ),
                _buildSettingsSlider(
                  context,
                  '弹幕区域',
                  '${(s.area * 100).round()}%',
                  s.area,
                  0.1,
                  1.0,
                  service.updateArea,
                ),
              ],
            );
          }),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSlider(
    BuildContext context,
    String label,
    String valueText,
    double value,
    double min,
    double max,
    Future<void> Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: (v) => onChanged(v),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              valueText,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showShieldWordsDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('弹幕屏蔽词'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        hintText: '输入屏蔽词，/正则/ 格式支持正则',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final word = textController.text.trim();
                      if (word.isNotEmpty) {
                        DanmakuSettingsService.instance.addShieldWord(word);
                        textController.clear();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: Obx(() {
                  final words =
                      DanmakuSettingsService.instance.settings.value.shieldWords;
                  if (words.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('暂无屏蔽词',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: words.length,
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      title: Text(words[i], style: const TextStyle(fontSize: 14)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => DanmakuSettingsService.instance
                            .removeShieldWord(words[i]),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    ).then((_) => textController.dispose());
  }

  Color _parseSCColor(String colorStr, Color fallback) {
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (_) {
      return fallback;
    }
  }
}
