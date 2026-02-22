import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../constants/platform_constants.dart';
import '../../routes/app_routes.dart';
import '../../utils/log_util.dart';

class ParseController extends GetxController {
  final textController = TextEditingController();
  final isParsing = false.obs;
  final errorMsg = ''.obs;
  final parsedPlatform = ''.obs;
  final parsedRoomId = ''.obs;

  int? _parsedPlatformIndex;

  @override
  void onInit() {
    super.onInit();
    _tryReadClipboard();
  }

  Future<void> _tryReadClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty && _looksLikeUrl(text)) {
        textController.text = text;
      }
    } catch (_) {}
  }

  bool _looksLikeUrl(String text) {
    return text.contains('bilibili.com') ||
        text.contains('douyu.com') ||
        text.contains('huya.com') ||
        text.contains('douyin.com') ||
        text.contains('b23.tv') ||
        text.contains('v.douyin.com');
  }

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }

  Future<void> parse() async {
    final url = textController.text.trim();
    if (url.isEmpty) {
      errorMsg.value = '请输入直播间链接';
      return;
    }

    isParsing.value = true;
    errorMsg.value = '';
    parsedPlatform.value = '';
    parsedRoomId.value = '';
    _parsedPlatformIndex = null;

    try {
      String resolvedUrl = url;

      // 处理短链接重定向
      if (_isShortLink(url)) {
        resolvedUrl = await _resolveShortLink(url);
      }

      final result = _parseUrl(resolvedUrl);
      if (result != null) {
        _parsedPlatformIndex = result.$1;
        parsedPlatform.value = PlatformConstants.getName(result.$1);
        parsedRoomId.value = result.$2;
      } else {
        errorMsg.value = '无法识别该链接，支持B站/斗鱼/虎牙/抖音直播间链接';
      }
    } catch (e, stack) {
      Log.e('Parse', '解析链接失败', e, stack);
      errorMsg.value = '解析失败: $e';
    } finally {
      isParsing.value = false;
    }
  }

  void goToLiveRoom() {
    if (_parsedPlatformIndex == null || parsedRoomId.value.isEmpty) return;
    Get.toNamed(
      AppRoutes.liveRoom,
      arguments: {
        'roomId': parsedRoomId.value,
        'platformIndex': _parsedPlatformIndex,
      },
    );
  }

  bool _isShortLink(String url) {
    return url.contains('b23.tv') || url.contains('v.douyin.com');
  }

  Future<String> _resolveShortLink(String url) async {
    String targetUrl = url;
    if (!targetUrl.startsWith('http')) {
      targetUrl = 'https://$targetUrl';
    }
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(Uri.parse(targetUrl));
        request.followRedirects = false;
        final response = await request.close();
        final location = response.headers.value('location');
        if (location != null && location.isNotEmpty) {
          Log.d('Parse', '短链接重定向: $location');
          return location;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      Log.w('Parse', '短链接解析失败，尝试原始链接: $e');
    }
    return targetUrl;
  }

  /// 解析 URL，返回 (platformIndex, roomId) 或 null
  (int, String)? _parseUrl(String url) {
    // B站: live.bilibili.com/{roomId}
    final biliMatch =
        RegExp(r'live\.bilibili\.com/(\d+)').firstMatch(url);
    if (biliMatch != null) {
      return (0, biliMatch.group(1)!);
    }

    // 斗鱼: douyu.com/{roomId} 或 douyu.com/topic/{...}?rid={roomId}
    final douyuMatch =
        RegExp(r'douyu\.com/(\d+)').firstMatch(url);
    if (douyuMatch != null) {
      return (1, douyuMatch.group(1)!);
    }
    final douyuTopicMatch =
        RegExp(r'douyu\.com/topic/\S+\?rid=(\d+)').firstMatch(url);
    if (douyuTopicMatch != null) {
      return (1, douyuTopicMatch.group(1)!);
    }

    // 虎牙: huya.com/{roomId}
    final huyaMatch =
        RegExp(r'huya\.com/(\w+)').firstMatch(url);
    if (huyaMatch != null) {
      return (2, huyaMatch.group(1)!);
    }

    // 抖音: live.douyin.com/{roomId}
    final douyinMatch =
        RegExp(r'live\.douyin\.com/(\d+)').firstMatch(url);
    if (douyinMatch != null) {
      return (3, douyinMatch.group(1)!);
    }

    return null;
  }
}
