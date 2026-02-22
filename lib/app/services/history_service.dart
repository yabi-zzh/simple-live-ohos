import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../models/room_models.dart';
import '../utils/log_util.dart';

class HistoryService extends GetxService {
  static HistoryService get instance => Get.find<HistoryService>();

  static const int maxHistory = 200;

  late Box _box;
  final histories = <HistoryRoom>[].obs;

  Future<HistoryService> init() async {
    _box = await Hive.openBox('history');
    _loadHistories();
    return this;
  }

  void _loadHistories() {
    try {
      final list = <HistoryRoom>[];
      for (var key in _box.keys) {
        final map = _box.get(key) as Map?;
        if (map != null) {
          list.add(HistoryRoom.fromMap(map));
        }
      }
      list.sort((a, b) => b.watchTime.compareTo(a.watchTime));
      histories.assignAll(list);
      Log.i('History', '加载历史: ${list.length} 条');
    } catch (e, stack) {
      Log.e('History', '加载历史失败', e, stack);
    }
  }

  /// 添加/更新观看记录
  Future<void> addHistory(HistoryRoom room) async {
    try {
      await _box.put(room.uniqueKey, room.toMap());
      // 移除旧记录再插入到头部
      histories.removeWhere((r) => r.uniqueKey == room.uniqueKey);
      histories.insert(0, room);
      // 超出上限时删除最旧的
      if (histories.length > maxHistory) {
        final removed = histories.removeLast();
        await _box.delete(removed.uniqueKey);
      }
    } catch (e, stack) {
      Log.e('History', '添加历史失败', e, stack);
    }
  }

  /// 删除单条记录
  Future<void> removeHistory(String roomId, int platformIndex) async {
    try {
      final key = '${platformIndex}_$roomId';
      await _box.delete(key);
      histories.removeWhere((r) => r.uniqueKey == key);
    } catch (e, stack) {
      Log.e('History', '删除历史失败', e, stack);
    }
  }

  /// 清空历史
  Future<void> clearAll() async {
    try {
      await _box.clear();
      histories.clear();
      Log.i('History', '清空历史');
    } catch (e, stack) {
      Log.e('History', '清空历史失败', e, stack);
      rethrow;
    }
  }
}
