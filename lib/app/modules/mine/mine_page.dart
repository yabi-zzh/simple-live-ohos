import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/favorite_service.dart';
import '../../services/history_service.dart';
import '../../services/danmaku_settings_service.dart';
import '../../services/storage_service.dart';
import '../index/index_controller.dart';

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
      body: ListView(
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
              icon: Icons.text_fields,
              title: '弹幕设置',
              onTap: () => _showDanmakuSettings(context),
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
    return Switch(
      value: Theme.of(context).brightness == Brightness.dark,
      onChanged: (dark) {
        final mode = dark ? ThemeMode.dark : ThemeMode.light;
        Get.changeThemeMode(mode);
        StorageService.instance.setValue('theme_mode', dark ? 'dark' : 'light');
      },
    );
  }

  void _showDanmakuSettings(BuildContext context) {
    final service = DanmakuSettingsService.instance;
    showModalBottomSheet(
      context: context,
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
            Text('版本: 1.0.0'),
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
