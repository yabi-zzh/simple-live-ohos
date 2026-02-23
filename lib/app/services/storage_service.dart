import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../utils/log_util.dart';

class StorageService extends GetxService {
  static StorageService get instance => Get.find<StorageService>();

  late Box _settingsBox;

  Box get settingsBox => _settingsBox;

  Future<StorageService> init() async {
    const hivePath = '/data/storage/el2/base/haps/entry/files/hive';
    Hive.init(hivePath);
    Log.d('Storage', 'Hive 初始化: $hivePath');
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
