import 'package:get/get.dart';
import '../models/danmaku_settings.dart';
import '../utils/log_util.dart';
import 'storage_service.dart';

class DanmakuSettingsService extends GetxService {
  static DanmakuSettingsService get instance => Get.find<DanmakuSettingsService>();

  static const String _key = 'danmaku_settings';

  final settings = DanmakuSettings().obs;

  // 屏蔽词编译缓存
  List<_ShieldMatcher> _regexMatchers = [];
  Set<String> _textMatchers = {};

  Future<DanmakuSettingsService> init() async {
    _load();
    return this;
  }

  void _load() {
    final map = StorageService.instance.getValue<Map?>(_key, null);
    if (map != null) {
      settings.value = DanmakuSettings.fromMap(Map<String, dynamic>.from(map));
    }
    _rebuildMatchers();
  }

  Future<void> _save() async {
    await StorageService.instance.setValue(_key, settings.value.toMap());
  }

  void _rebuildMatchers() {
    _regexMatchers = [];
    _textMatchers = {};
    for (final word in settings.value.shieldWords) {
      if (word.startsWith('/') && word.endsWith('/') && word.length > 2) {
        try {
          final pattern = word.substring(1, word.length - 1);
          _regexMatchers.add(_ShieldMatcher(word, RegExp(pattern, caseSensitive: false)));
        } catch (e) {
          Log.w('DanmakuSettings', '无效的正则屏蔽词: $word ($e)');
        }
      } else {
        _textMatchers.add(word.toLowerCase());
      }
    }
  }

  Future<void> updateFontSize(double value) async {
    settings.value = settings.value.copyWith(fontSize: value);
    await _save();
  }

  Future<void> updateOpacity(double value) async {
    settings.value = settings.value.copyWith(opacity: value);
    await _save();
  }

  Future<void> updateDuration(double value) async {
    settings.value = settings.value.copyWith(duration: value);
    await _save();
  }

  Future<void> updateArea(double value) async {
    settings.value = settings.value.copyWith(area: value);
    await _save();
  }

  Future<void> addShieldWord(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;
    final words = List<String>.from(settings.value.shieldWords);
    if (words.contains(trimmed)) return;
    words.add(trimmed);
    settings.value = settings.value.copyWith(shieldWords: words);
    _rebuildMatchers();
    await _save();
  }

  Future<void> removeShieldWord(String word) async {
    final words = List<String>.from(settings.value.shieldWords);
    words.remove(word);
    settings.value = settings.value.copyWith(shieldWords: words);
    _rebuildMatchers();
    await _save();
  }

  /// 检查消息是否匹配屏蔽词（普通文本用 Set 加速，正则用预编译缓存）
  bool shouldFilter(String message) {
    if (_textMatchers.isEmpty && _regexMatchers.isEmpty) return false;
    final lowerMessage = message.toLowerCase();
    // 先检查普通文本（快速路径）
    for (final word in _textMatchers) {
      if (lowerMessage.contains(word)) return true;
    }
    // 再检查正则
    for (final matcher in _regexMatchers) {
      if (matcher.regex!.hasMatch(message)) return true;
    }
    return false;
  }
}

class _ShieldMatcher {
  final String word;
  final RegExp? regex;
  const _ShieldMatcher(this.word, this.regex);
}
