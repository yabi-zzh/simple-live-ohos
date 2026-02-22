import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/log_util.dart';

class StorageService extends GetxService {
  static StorageService get instance => Get.find<StorageService>();

  late Box _settingsBox;

  Box get settingsBox => _settingsBox;

  Future<StorageService> init() async {
    try {
      // 优先使用 hive_flutter 的路径解析（依赖 path_provider）
      await Hive.initFlutter('hive');
      Log.d('Storage', 'Hive.initFlutter 成功');
    } catch (e) {
      // OHOS 沙箱路径回退
      const ohosPath = '/data/storage/el2/base/haps/entry/files/hive';
      Hive.init(ohosPath);
      Log.d('Storage', 'Hive 回退到 OHOS 沙箱路径: $ohosPath');
    }
    _settingsBox = await Hive.openBox('settings');
    return this;
  }

  T getValue<T>(String key, T defaultValue) {
    return _settingsBox.get(key, defaultValue: defaultValue) as T;
  }

  Future<void> setValue<T>(String key, T value) async {
    await _settingsBox.put(key, value);
  }

  Future<void> removeValue(String key) async {
    await _settingsBox.delete(key);
  }
}
