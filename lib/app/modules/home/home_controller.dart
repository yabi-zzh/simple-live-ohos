import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import '../../services/platform_service.dart';
import '../../utils/log_util.dart';

class HomeController extends GetxController {
  final currentPlatform = 0.obs;
  final rooms = <LiveRoomItem>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;

  // 每个平台独立缓存
  final Map<int, List<LiveRoomItem>> _cache = {};
  final Map<int, int> _pageCache = {};
  final Map<int, bool> _hasMoreCache = {};

  LiveSite get currentSite => PlatformService.instance.getSite(currentPlatform.value);

  @override
  void onInit() {
    super.onInit();
    loadRooms();
  }

  void switchPlatform(int index) {
    if (currentPlatform.value == index) return;
    currentPlatform.value = index;

    // 有缓存直接用，不发请求
    if (_cache.containsKey(index)) {
      rooms.assignAll(_cache[index]!);
      hasMore.value = _hasMoreCache[index] ?? true;
      isLoading.value = false;
      return;
    }

    // 无缓存才加载
    rooms.clear();
    isLoading.value = true;
    loadRooms();
  }

  Future<void> refreshRooms() async {
    final platform = currentPlatform.value;
    _pageCache[platform] = 1;
    _hasMoreCache[platform] = true;
    hasMore.value = true;
    isLoading.value = true;
    rooms.clear();
    _cache.remove(platform);
    await loadRooms();
  }

  Future<void> loadRooms() async {
    final platform = currentPlatform.value;
    final page = _pageCache[platform] ?? 1;
    try {
      final result = await currentSite.getRecommendRooms(page: page);
      // 防止切换平台后旧请求回来覆盖数据
      if (currentPlatform.value != platform) return;

      if (page == 1) {
        rooms.assignAll(result.items);
      } else {
        rooms.addAll(result.items);
      }
      hasMore.value = result.hasMore;
      _pageCache[platform] = page + 1;
      _hasMoreCache[platform] = result.hasMore;
      _cache[platform] = List.from(rooms);
    } catch (e, stack) {
      Log.e('Home', '加载推荐列表失败', e, stack);
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    await loadRooms();
  }
}
