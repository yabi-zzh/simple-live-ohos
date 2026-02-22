import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import '../../services/platform_service.dart';
import '../../utils/log_util.dart';

class CategoryController extends GetxController {
  final categories = <LiveCategory>[].obs;
  final isLoading = true.obs;
  final currentPlatform = 0.obs;

  // 每个平台独立缓存
  final Map<int, List<LiveCategory>> _cache = {};

  LiveSite get currentSite => PlatformService.instance.getSite(currentPlatform.value);

  @override
  void onInit() {
    super.onInit();
    loadCategories();
  }

  void switchPlatform(int index) {
    if (currentPlatform.value == index) return;
    currentPlatform.value = index;

    if (_cache.containsKey(index)) {
      categories.assignAll(_cache[index]!);
      isLoading.value = false;
      return;
    }

    categories.clear();
    loadCategories();
  }

  Future<void> refreshCategories() async {
    _cache.remove(currentPlatform.value);
    await loadCategories();
  }

  Future<void> loadCategories() async {
    final platform = currentPlatform.value;
    isLoading.value = true;
    try {
      final result = await currentSite.getCategores();
      if (currentPlatform.value != platform) return;

      categories.assignAll(result);
      _cache[platform] = List.from(result);
    } catch (e, stack) {
      Log.e('Category', '加载分类失败', e, stack);
    } finally {
      isLoading.value = false;
    }
  }
}
