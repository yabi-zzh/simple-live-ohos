
import { FlutterAbility, FlutterEngine, MethodChannel } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import AVSessionPlugin from '../plugins/AVSessionPlugin';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'EntryAbility';
const DOMAIN = 0xFF01;

export default class EntryAbility extends FlutterAbility {
  private lifecycleChannel: MethodChannel | null = null;

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    flutterEngine.getPlugins()?.add(new AVSessionPlugin());
    this.lifecycleChannel = new MethodChannel(
      flutterEngine.getDartExecutor().getBinaryMessenger(),
      'com.simplelive/lifecycle'
    );
    hilog.info(DOMAIN, TAG, '%{public}s', 'Lifecycle MethodChannel created');
  }

  onBackground() {
    // 在 super 之前发送，确保 Dart 在 surface 销毁前收到通知
    hilog.info(DOMAIN, TAG, '%{public}s', 'onBackground, notifying Dart');
    this.lifecycleChannel?.invokeMethod('onBackground', null);
    super.onBackground();
  }

  onForeground() {
    super.onForeground();
    hilog.info(DOMAIN, TAG, '%{public}s', 'onForeground, notifying Dart');
    this.lifecycleChannel?.invokeMethod('onForeground', null);
  }
}
