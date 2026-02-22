import 'package:flutter/material.dart';

/// 平台常量定义
class PlatformConstants {
  PlatformConstants._();

  /// 平台索引
  static const int bilibili = 0;
  static const int douyu = 1;
  static const int huya = 2;
  static const int douyin = 3;

  /// 平台完整名称
  static const Map<int, String> platformNames = {
    bilibili: '哔哩哔哩',
    douyu: '斗鱼',
    huya: '虎牙',
    douyin: '抖音',
  };

  /// 平台短名称
  static const Map<int, String> platformShortNames = {
    bilibili: 'B站',
    douyu: '斗鱼',
    huya: '虎牙',
    douyin: '抖音',
  };

  /// 平台主题色
  static const Map<int, Color> platformColors = {
    bilibili: Color(0xFFFF6699),
    douyu: Color(0xFFFF7F00),
    huya: Color(0xFFFFCC00),
    douyin: Color(0xFF000000),
  };

  /// 获取平台名称
  static String getName(int index) => platformNames[index] ?? '未知';

  /// 获取平台短名称
  static String getShortName(int index) => platformShortNames[index] ?? '';

  /// 获取平台颜色
  static Color getColor(int index) => platformColors[index] ?? Colors.grey;
}
