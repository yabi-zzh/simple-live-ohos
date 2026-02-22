import { webview } from '@kit.ArkWeb';

/**
 * JS 执行引擎单例，持有 WebviewController 供 Index.ets 绑定 Web 组件
 */
export class JsExecutorEngine {
  private static _instance: JsExecutorEngine | null = null;
  private controller: webview.WebviewController = new webview.WebviewController();
  private ready: boolean = false;
  private readyResolve: (() => void) | null = null;
  private readyPromise: Promise<void> | null = null;

  static get instance(): JsExecutorEngine {
    if (!JsExecutorEngine._instance) {
      JsExecutorEngine._instance = new JsExecutorEngine();
    }
    return JsExecutorEngine._instance;
  }

  getController(): webview.WebviewController {
    return this.controller;
  }

  onPageReady(): void {
    this.ready = true;
    if (this.readyResolve) {
      this.readyResolve();
      this.readyResolve = null;
    }
  }

  private waitReady(): Promise<void> {
    if (this.ready) {
      return Promise.resolve();
    }
    if (!this.readyPromise) {
      this.readyPromise = new Promise<void>((resolve: () => void, reject: (reason: Error) => void) => {
        this.readyResolve = resolve;
        setTimeout(() => {
          if (!this.ready) {
            reject(new Error('JS engine init timeout (10s)'));
          }
        }, 10000);
      });
    }
    return this.readyPromise;
  }

  async execute(jsCode: string): Promise<string> {
    await this.waitReady();

    // 直接执行，不包装 IIFE，runJavaScript 会返回最后一个表达式的值
    let result: string;
    try {
      result = await this.controller.runJavaScript(jsCode);
    } catch (e) {
      throw new Error('runJavaScript failed: ' + e);
    }

    // runJavaScript 返回值带引号，需要去掉
    let output: string = result;
    if (output.startsWith('"') && output.endsWith('"')) {
      output = output.substring(1, output.length - 1);
    }

    return output;
  }
}
