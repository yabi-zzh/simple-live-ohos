import 'package:simple_live_core/simple_live_core.dart';
import 'js_executor_ohos.dart';

/// HarmonyOS 平台的 JsExecutor 实现
class JsExecutorOhosImpl implements JsExecutor {
  @override
  Future<String> execute(String jsCode) async {
    return await JsExecutorOhos.execute(jsCode);
  }

  @override
  void dispose() {
    JsExecutorOhos.dispose();
  }
}
