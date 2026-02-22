import 'dart:async';
import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import '../../services/platform_service.dart';
import '../../services/storage_service.dart';
import '../../utils/log_util.dart';

class SearchController extends GetxController {
  final keyword = ''.obs;
  final rooms = <LiveRoomItem>[].obs;
  final anchors = <LiveAnchorItem>[].obs;
  final isLoading = false.obs;
  final hasMore = true.obs;
  final currentPlatform = 0.obs;
  final searchType = 0.obs; // 0: 房间, 1: 主播
  int _page = 1;
  Timer? _debounceTimer;

  // 搜索历史
  final searchHistory = <String>[].obs;
  static const int _maxHistory = 20;
  static const String _historyKey = 'search_history';

  LiveSite get currentSite => PlatformService.instance.getSite(currentPlatform.value);

  @override
  void onInit() {
    super.onInit();
    _loadHistory();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }

  void _loadHistory() {
    try {
      final list = StorageService.instance.getValue<List?>(_historyKey, null);
      if (list != null) {
        searchHistory.assignAll(list.cast<String>());
      }
    } catch (e) {
      Log.d('Search', '加载搜索历史失败: $e');
    }
  }

  void _saveHistory() {
    try {
      StorageService.instance.setValue(_historyKey, searchHistory.toList());
    } catch (e) {
      Log.d('Search', '保存搜索历史失败: $e');
    }
  }

  void _addToHistory(String text) {
    searchHistory.remove(text);
    searchHistory.insert(0, text);
    if (searchHistory.length > _maxHistory) {
      searchHistory.removeRange(_maxHistory, searchHistory.length);
    }
    _saveHistory();
  }

  void removeHistory(String text) {
    searchHistory.remove(text);
    _saveHistory();
  }

  void clearHistory() {
    searchHistory.clear();
    _saveHistory();
  }

  void switchPlatform(int index) {
    if (currentPlatform.value == index) return;
    currentPlatform.value = index;
    if (keyword.value.isNotEmpty) {
      search(keyword.value);
    }
  }

  void switchSearchType(int type) {
    if (searchType.value == type) return;
    searchType.value = type;
    if (keyword.value.isNotEmpty) {
      search(keyword.value);
    }
  }

  Future<void> search(String text) async {
    keyword.value = text;
    _page = 1;
    hasMore.value = true;
    rooms.clear();
    anchors.clear();
    if (text.isEmpty) return;
    _addToHistory(text);
    // 防抖：快速切换平台/类型时只执行最后一次
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      isLoading.value = true;
      await _doSearch();
    });
  }

  Future<void> _doSearch() async {
    try {
      if (searchType.value == 0) {
        final result = await currentSite.searchRooms(keyword.value, page: _page);
        if (_page == 1) {
          rooms.assignAll(result.items);
        } else {
          rooms.addAll(result.items);
        }
        hasMore.value = result.hasMore;
      } else {
        final result = await currentSite.searchAnchors(keyword.value, page: _page);
        if (_page == 1) {
          anchors.assignAll(result.items);
        } else {
          anchors.addAll(result.items);
        }
        hasMore.value = result.hasMore;
      }
      _page++;
    } catch (e, stack) {
      Log.e('Search', '搜索失败', e, stack);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoading.value || !hasMore.value) return;
    isLoading.value = true;
    await _doSearch();
  }
}
