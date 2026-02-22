import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult
} from '@ohos/flutter_ohos';
import { BusinessError } from '@kit.BasicServicesKit';
import { JsExecutorEngine } from './JsExecutorEngine';

export default class JsExecutorOhosPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  getUniqueClassName(): string {
    return 'JsExecutorOhosPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'js_executor_ohos');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel !== null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'init':
        result.success(null);
        break;
      case 'execute': {
        const code: string = call.argument('code') as string;
        if (!code) {
          result.error('INVALID_ARGUMENT', 'JS code is required', null);
          return;
        }
        JsExecutorEngine.instance.execute(code)
          .then((jsResult: string) => {
            result.success(jsResult);
          })
          .catch((error: BusinessError) => {
            result.error('EXECUTE_ERROR', error.message, null);
          });
        break;
      }
      case 'dispose':
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }
}
