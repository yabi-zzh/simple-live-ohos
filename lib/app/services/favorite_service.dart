import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../models/room_models.dart';
import '../utils/log_util.dart';
import 'platform_service.dart';

class FavoriteService extends GetxService {
  static FavoriteService get instance => Get.find<FavoriteService>();

  late Box _box;
  final favorites = <FavoriteRoom>[].obs;

  Future<FavoriteService> init() async {
    _box = await Hive.openBox('favorites');
    _loadFavorites();
    return this;
  }

  void _loadFavorites() {
    try {
      final list = <FavoriteRoom>[];
      for (var key in _box.keys) {
        final map = _box.get(key) as Map?;
        if (map != null) {
          list.add(FavoriteRoom.fromMap(map));
        }
      }
      // 按添加时间倒序
      list.sort((a, b) => b.addTime.compareTo(a.addTime));
      favorites.assignAll(list);
      Log.i('Favorite', '加载收藏: ${list.length} 个');
    } catch (e, stack) {
      Log.e('Favorite', '加载收藏失败', e, stack);
    }
  }

  /// 是否已收藏（基于 observable 列表，可在 Obx 中使用）
  bool isFavorite(String roomId, int platformIndex) {
    final key = '${platformIndex}_$roomId';
    return favorites.any((r) => r.uniqueKey == key);
  }

  /// 添加收藏
  Future<void> addFavorite(FavoriteRoom room) async {
    try {
      await _box.put(room.uniqueKey, room.toMap());
      favorites.insert(0, room);
      Log.i('Favorite', '添加收藏: ${room.title}');
    } catch (e, stack) {
      Log.e('Favorite', '添加收藏失败', e, stack);
      rethrow;
    }
  }

  /// 移除收藏
  Future<void> removeFavorite(String roomId, int platformIndex) async {
    try {
      final key = '${platformIndex}_$roomId';
      await _box.delete(key);
      favorites.removeWhere((r) => r.uniqueKey == key);
      Log.i('Favorite', '移除收藏: $key');
    } catch (e, stack) {
      Log.e('Favorite', '移除收藏失败', e, stack);
      rethrow;
    }
  }

  /// 更新收藏信息（标题、主播名、封面）
  Future<void> updateFavorite(FavoriteRoom room) async {
    try {
      final existing = favorites.firstWhereOrNull((r) => r.uniqueKey == room.uniqueKey);
      if (existing != null) {
        existing.title = room.title;
        existing.userName = room.userName;
        existing.cover = room.cover;
        await _box.put(room.uniqueKey, room.toMap());
        favorites.refresh();
      }
    } catch (e, stack) {
      Log.e('Favorite', '更新收藏失败', e, stack);
    }
  }

  /// 清空收藏
  Future<void> clearAll() async {
    try {
      await _box.clear();
      favorites.clear();
      Log.i('Favorite', '清空收藏');
    } catch (e, stack) {
      Log.e('Favorite', '清空收藏失败', e, stack);
      rethrow;
    }
  }

  /// 刷新所有关注的开播状态
  final isChecking = false.obs;
  DateTime? _lastRefreshTime;

  /// 自动刷新（距上次刷新超过5分钟才执行）
  Future<void> autoRefreshIfNeeded() async {
    if (_lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!).inMinutes < 5) {
      return;
    }
    await refreshLiveStatus();
  }

  Future<void> refreshLiveStatus() async {
    if (isChecking.value || favorites.isEmpty) return;
    isChecking.value = true;
    try {
      // 并发请求，每批10个，每个请求5秒超时
      final batch = 10;
      for (var i = 0; i < favorites.length; i += batch) {
        final end = (i + batch).clamp(0, favorites.length);
        await Future.wait(
          favorites.sublist(i, end).map((room) =>
            _checkRoomStatus(room).timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                room.isLive = null;
              },
            )
          ),
        );
        // 分批刷新 UI
        favorites.refresh();
      }
      // 开播的排前面
      favorites.sort((a, b) {
        final aLive = a.isLive == true ? 0 : 1;
        final bLive = b.isLive == true ? 0 : 1;
        if (aLive != bLive) return aLive.compareTo(bLive);
        return b.addTime.compareTo(a.addTime);
      });
      favorites.refresh();
      _lastRefreshTime = DateTime.now();
      Log.i('Favorite', '开播状态刷新完成');
    } catch (e, stack) {
      Log.e('Favorite', '刷新开播状态失败', e, stack);
    } finally {
      isChecking.value = false;
    }
  }

  Future<void> _checkRoomStatus(FavoriteRoom room) async {
    try {
      final site = PlatformService.instance.getSite(room.platformIndex);
      final detail = await site.getRoomDetail(roomId: room.roomId);
      room.isLive = detail.status;
      room.title = detail.title;
      room.userName = detail.userName;
      if (detail.cover.isNotEmpty) {
        room.cover = detail.cover;
      }
    } catch (e) {
      Log.d('Favorite', '检查 ${room.userName} 开播状态失败: $e');
      room.isLive = null;
    }
  }
}
