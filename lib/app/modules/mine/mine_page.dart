import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../main.dart';
import '../../constants/app_constants.dart';
import '../../services/favorite_service.dart';
import '../../services/history_service.dart';
import '../../services/danmaku_settings_service.dart';
import '../../services/storage_service.dart';
import '../index/index_controller.dart';
import '../../utils/responsive.dart';

class MinePage extends StatelessWidget {
  MinePage({super.key});

  // 用于触发局部 rebuild 的计数器
  final _refreshKey = 0.obs;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: Responsive.constrainedContent(
        child: ListView(
        children: [
          // 统计卡片
          _buildStatsCard(context, colorScheme),
          const SizedBox(height: 10),
          // 功能列表
          _buildSection(context, [
            _MenuItem(
              icon: Icons.history,
              title: '观看历史',
              onTap: () => Get.toNamed('/history'),
            ),
            _MenuItem(
              icon: Icons.favorite_border,
              title: '我的关注',
              subtitle: Obx(() => Text(
                    '${FavoriteService.instance.favorites.length} 个',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )),
              onTap: () {
                // 切换到关注 Tab (index 2)
                final indexController = Get.find<IndexController>();
                indexController.changePage(2);
              },
            ),
            _MenuItem(
              icon: Icons.link,
              title: '链接解析',
              onTap: () => Get.toNamed('/parse'),
            ),
          ]),
          const SizedBox(height: 10),
          _buildSection(context, [
            _MenuItem(
              icon: Icons.dark_mode_outlined,
              title: '深色模式',
              trailing: _buildThemeSwitch(context),
            ),
            _MenuItem(
              icon: Icons.hd_outlined,
              title: '默认清晰度',
              subtitle: Obx(() {
                _refreshKey.value;
                return _buildQualityLabel(colorScheme);
              }),
              onTap: () => _showQualityPicker(context),
            ),
            _MenuItem(
              icon: Icons.phonelink_outlined,
              title: '后台播放模式',
              subtitle: Obx(() {
                _refreshKey.value;
                return _buildBgPlayModeLabel(colorScheme);
              }),
              onTap: () => _showBgPlayModePicker(context),
            ),
            _MenuItem(
              icon: Icons.memory,
              title: '硬件解码',
              trailing: Obx(() {
                _refreshKey.value;
                return _buildHardwareDecodeSwitch();
              }),
            ),
            _MenuItem(
              icon: Icons.fullscreen,
              title: '进入直播间自动全屏',
              trailing: Obx(() {
                _refreshKey.value;
                return _buildAutoFullscreenSwitch();
              }),
            ),
            _MenuItem(
              icon: Icons.storage_outlined,
              title: '播放器缓冲区',
              subtitle: Obx(() {
                _refreshKey.value;
                return _buildBufferSizeLabel(colorScheme);
              }),
              onTap: () => _showBufferSizePicker(context),
            ),
            _MenuItem(
              icon: Icons.timer_outlined,
              title: '定时关闭',
              subtitle: Obx(() {
                _refreshKey.value;
                return _buildAutoExitLabel(colorScheme);
              }),
              onTap: () => _showAutoExitPicker(context),
            ),
          ]),
          const SizedBox(height: 10),
          _buildSection(context, [
            _MenuItem(
              icon: Icons.text_fields,
              title: '弹幕设置',
              onTap: () => _showDanmakuSettings(context),
            ),
            _MenuItem(
              icon: Icons.chat_outlined,
              title: '聊天区文字大小',
              subtitle: Obx(() {
                _refreshKey.value;
                return _buildChatTextSizeLabel(colorScheme);
              }),
              onTap: () => _showChatTextSizePicker(context),
            ),
          ]),
          const SizedBox(height: 10),
          _buildSection(context, [
            _MenuItem(
              icon: Icons.cleaning_services_outlined,
              title: '清除图片缓存',
              subtitle: Obx(() {
                _refreshKey.value;
                return _buildCacheSize(colorScheme);
              }),
              onTap: () => _clearImageCache(context),
            ),
            _MenuItem(
              icon: Icons.volunteer_activism_outlined,
              title: '捐赠打赏',
              onTap: () => _showDonateDialog(context),
            ),
            _MenuItem(
              icon: Icons.info_outline,
              title: '关于',
              onTap: () => _showAboutDialog(context),
            ),
          ]),
          const SizedBox(height: 16),
        ],
      ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Obx(() => _buildStatItem(
                    context,
                    Icons.favorite,
                    '${FavoriteService.instance.favorites.length}',
                    '关注',
                    colorScheme.primary,
                  )),
              Obx(() {
                final liveCount = FavoriteService.instance.favorites
                    .where((r) => r.isLive == true)
                    .length;
                return _buildStatItem(
                  context,
                  Icons.live_tv,
                  '$liveCount',
                  '正在直播',
                  Colors.red,
                );
              }),
              Obx(() => _buildStatItem(
                    context,
                    Icons.history,
                    '${HistoryService.instance.histories.length}',
                    '历史',
                    colorScheme.tertiary,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String count,
      String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, List<_MenuItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: items.map((item) {
            return ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              subtitle: item.subtitle,
              trailing: item.trailing ??
                  (item.onTap != null
                      ? const Icon(Icons.chevron_right, size: 20)
                      : null),
              onTap: item.onTap,
            );
          }).toList(),
        ),
      ),
    );
  }

  static const _qualityLabels = ['最高画质', '较高画质', '中等画质', '最低画质'];

  Widget _buildQualityLabel(ColorScheme colorScheme) {
    final pref = StorageService.instance.getValue<int>('preferred_quality', 0);
    return Text(
      _qualityLabels[pref.clamp(0, 3)],
      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
    );
  }

  void _showQualityPicker(BuildContext context) {
    final current = StorageService.instance.getValue<int>('preferred_quality', 0);
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: Responsive.maxSheetWidth),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('默认清晰度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ...List.generate(_qualityLabels.length, (i) => ListTile(
              title: Text(_qualityLabels[i]),
              trailing: i == current ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () {
                StorageService.instance.setValue('preferred_quality', i);
                Navigator.pop(ctx);
                _refreshKey.value++;
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSwitch(BuildContext context) {
    return Obx(() => Switch(
      value: MyApp.isDark.value,
      onChanged: (dark) {
        MyApp.isDark.value = dark;
        StorageService.instance.setValue('theme_mode', dark ? 'dark' : 'light');
      },
    ));
  }

  // ==================== 后台播放模式 ====================

  static const _bgPlayModeLabels = ['继续播放', '静音保持连接', '暂停'];

  Widget _buildBgPlayModeLabel(ColorScheme colorScheme) {
    final mode = StorageService.instance.getValue<int>('bg_play_mode', 1);
    return Text(
      _bgPlayModeLabels[mode.clamp(0, 2)],
      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
    );
  }

  void _showBgPlayModePicker(BuildContext context) {
    final current = StorageService.instance.getValue<int>('bg_play_mode', 1);
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: Responsive.maxSheetWidth),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('后台播放模式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ...List.generate(_bgPlayModeLabels.length, (i) => ListTile(
              title: Text(_bgPlayModeLabels[i]),
              subtitle: Text(
                [
                  '后台继续播放声音',
                  '后台静音但保持流连接，回前台快速恢复',
                  '后台暂停播放，回前台重新连接',
                ][i],
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              trailing: i == current ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () {
                StorageService.instance.setValue('bg_play_mode', i);
                Navigator.pop(ctx);
                _refreshKey.value++;
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ==================== 硬件解码 ====================

  Widget _buildHardwareDecodeSwitch() {
    final enabled = StorageService.instance.getValue<bool>('hardware_decode', true);
    return Switch(
      value: enabled,
      onChanged: (v) {
        StorageService.instance.setValue('hardware_decode', v);
        _refreshKey.value++;
      },
    );
  }

  // ==================== 自动全屏 ====================

  Widget _buildAutoFullscreenSwitch() {
    final enabled = StorageService.instance.getValue<bool>('auto_fullscreen', false);
    return Switch(
      value: enabled,
      onChanged: (v) {
        StorageService.instance.setValue('auto_fullscreen', v);
        _refreshKey.value++;
      },
    );
  }

  // ==================== 缓冲区大小 ====================

  static const _bufferSizeOptions = [8, 16, 32, 64, 128];

  Widget _buildBufferSizeLabel(ColorScheme colorScheme) {
    final mb = StorageService.instance.getValue<int>('buffer_size', 32);
    return Text(
      '${mb}MB',
      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
    );
  }

  void _showBufferSizePicker(BuildContext context) {
    final current = StorageService.instance.getValue<int>('buffer_size', 32);
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: Responsive.maxSheetWidth),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('播放器缓冲区大小', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ..._bufferSizeOptions.map((mb) => ListTile(
              title: Text('${mb}MB'),
              trailing: mb == current ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () {
                StorageService.instance.setValue('buffer_size', mb);
                Navigator.pop(ctx);
                _refreshKey.value++;
              },
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '修改后在下次进入直播间时生效',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ==================== 定时关闭 ====================

  static const _autoExitOptions = [0, 15, 30, 60, 90, 120];

  Widget _buildAutoExitLabel(ColorScheme colorScheme) {
    final min = StorageService.instance.getValue<int>('auto_exit_minutes', 0);
    return Text(
      min == 0 ? '关闭' : '$min 分钟',
      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
    );
  }

  void _showAutoExitPicker(BuildContext context) {
    final current = StorageService.instance.getValue<int>('auto_exit_minutes', 0);
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: Responsive.maxSheetWidth),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('定时关闭直播间', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ..._autoExitOptions.map((min) => ListTile(
              title: Text(min == 0 ? '关闭' : '$min 分钟'),
              trailing: min == current ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () {
                StorageService.instance.setValue('auto_exit_minutes', min);
                Navigator.pop(ctx);
                _refreshKey.value++;
              },
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '进入直播间后自动倒计时关闭',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ==================== 聊天区文字大小 ====================

  Widget _buildChatTextSizeLabel(ColorScheme colorScheme) {
    final size = StorageService.instance.getValue<double>('chat_text_size', 13.0);
    return Text(
      '${size.round()}',
      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
    );
  }

  void _showChatTextSizePicker(BuildContext context) {
    final current = StorageService.instance.getValue<double>('chat_text_size', 13.0).obs;
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: Responsive.maxSheetWidth),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('聊天区文字大小', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Obx(() => Row(
                children: [
                  const SizedBox(width: 80, child: Text('字号', style: TextStyle(fontSize: 14))),
                  Expanded(
                    child: Slider(
                      value: current.value.clamp(10.0, 20.0),
                      min: 10,
                      max: 20,
                      divisions: 10,
                      onChanged: (v) {
                        current.value = v;
                        StorageService.instance.setValue('chat_text_size', v);
                        _refreshKey.value++;
                      },
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${current.value.round()}',
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showDanmakuSettings(BuildContext context) {
    final service = DanmakuSettingsService.instance;
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: Responsive.maxSheetWidth),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Obx(() {
            final s = service.settings.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '弹幕设置',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.block, size: 18),
                      label: Obx(() => Text(
                            '屏蔽词 (${service.settings.value.shieldWords.length})',
                          )),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showShieldWordsDialog(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSliderItem(
                  context,
                  '字体大小',
                  '${s.fontSize.round()}',
                  s.fontSize,
                  10,
                  30,
                  service.updateFontSize,
                ),
                _buildSliderItem(
                  context,
                  '弹幕透明度',
                  '${(s.opacity * 100).round()}%',
                  s.opacity,
                  0.1,
                  1.0,
                  service.updateOpacity,
                ),
                _buildSliderItem(
                  context,
                  '弹幕速度',
                  '${s.duration.round()}秒',
                  s.duration,
                  3,
                  15,
                  service.updateDuration,
                ),
                _buildSliderItem(
                  context,
                  '弹幕区域',
                  '${(s.area * 100).round()}%',
                  s.area,
                  0.1,
                  1.0,
                  service.updateArea,
                ),
                _buildSliderItem(
                  context,
                  '描边宽度',
                  s.strokeWidth.toStringAsFixed(1),
                  s.strokeWidth,
                  0.0,
                  5.0,
                  service.updateStrokeWidth,
                ),
                _buildFontWeightItem(context, s.fontWeight, service),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSliderItem(
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

  Widget _buildFontWeightItem(BuildContext context, int weightIndex, DanmakuSettingsService service) {
    const labels = ['w100', 'w200', 'w300', 'w400', 'w500', 'w600', 'w700', 'w800', 'w900'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 80, child: Text('字体粗细', style: TextStyle(fontSize: 14))),
          Expanded(
            child: Slider(
              value: weightIndex.toDouble(),
              min: 0,
              max: 8,
              divisions: 8,
              onChanged: (v) => service.updateFontWeight(v.round()),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              labels[weightIndex.clamp(0, 8)],
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
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

  Widget _buildCacheSize(ColorScheme colorScheme) {
    final cache = PaintingBinding.instance.imageCache;
    final count = cache.currentSize;
    final bytes = cache.currentSizeBytes;
    final mb = (bytes / 1024 / 1024).toStringAsFixed(1);
    return Text(
      '$count 张 / ${mb}MB',
      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
    );
  }

  void _clearImageCache(BuildContext context) {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    Get.snackbar(
      '提示',
      '图片缓存已清除',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(12),
    );
    _refreshKey.value++;
  }

  void _showDonateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('捐赠打赏'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('如果觉得本项目对你有帮助，欢迎打赏支持'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/qr_wechat.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('微信支付', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/qr_alipay.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('支付宝', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simple Live'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: ${AppConstants.version}'),
            SizedBox(height: 8),
            Text('多平台直播聚合应用'),
            SizedBox(height: 4),
            Text('支持哔哩哔哩、斗鱼、虎牙、抖音'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
}
