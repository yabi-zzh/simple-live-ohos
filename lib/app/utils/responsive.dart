import 'package:flutter/material.dart';

/// 响应式布局断点工具
///
/// Material 3 断点标准：
/// - compact:  < 600  (手机竖屏)
/// - medium:   600~839 (手机横屏 / 小平板)
/// - expanded: >= 840  (平板 / 桌面)
class Responsive {
  Responsive._();

  static const double compactBreakpoint = 600;
  static const double expandedBreakpoint = 840;

  /// 列表/详情页内容最大宽度
  static const double maxContentWidth = 640;

  /// BottomSheet 最大宽度
  static const double maxSheetWidth = 480;

  /// 是否为平板/桌面宽度 (>= 600)
  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= compactBreakpoint;
  }

  /// 是否为大屏/桌面宽度 (>= 840)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= expandedBreakpoint;
  }

  /// 不依赖 BuildContext 的平板判断（基于物理屏幕短边）
  /// 可在 Controller / onClose 等无 context 的场景使用
  static bool get isTabletDevice {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return view.physicalSize.shortestSide / view.devicePixelRatio >= compactBreakpoint;
  }

  /// 根据可用宽度计算 GridView 列数
  static int gridCrossAxisCount(double width) {
    if (width >= 1200) return 5;
    if (width >= expandedBreakpoint) return 4;
    if (width >= compactBreakpoint) return 3;
    return 2;
  }

  /// 根据可用宽度和列数计算卡片宽高比
  /// 卡片结构：16:9 封面 + ~64px 文字区域（标题2行 + 主播名1行 + 内边距）
  static double gridChildAspectRatio(double availableWidth, int crossAxisCount) {
    final contentWidth = availableWidth - 16; // GridView padding 8*2
    final spacing = (crossAxisCount - 1) * 8.0; // crossAxisSpacing
    final cardWidth = (contentWidth - spacing) / crossAxisCount;
    final coverHeight = cardWidth * 9 / 16;
    const textAreaHeight = 66.0;
    return cardWidth / (coverHeight + textAreaHeight);
  }

  /// 包裹内容区域，在宽屏上居中并限制最大宽度
  static Widget constrainedContent({
    required Widget child,
    double maxWidth = maxContentWidth,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
