import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import '../../services/platform_service.dart';
import '../../utils/log_util.dart';

class CategoryRoomController extends GetxController {
  final LiveSubCategory subCategory;
  final int platformIndex;

  CategoryRoomController({required this.subCategory, required this.platformIndex});

  final rooms = <LiveRoomItem>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  int _page = 1;

  LiveSite get site => PlatformService.instance.getSite(platformIndex);

  @override
  void onInit() {
    super.onInit();
    loadRooms();
  }

  Future<void> refreshRooms() async {
    _page = 1;
    hasMore.value = true;
    isLoading.value = true;
    rooms.clear();
    await loadRooms();
  }

  Future<void> loadRooms() async {
    try {
      final result = await site.getCategoryRooms(subCategory, page: _page);
      if (_page == 1) {
        rooms.assignAll(result.items);
      } else {
        rooms.addAll(result.items);
      }
      hasMore.value = result.hasMore;
      _page++;
    } catch (e, stack) {
      Log.e('CategoryRoom', '加载分类房间失败', e, stack);
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
