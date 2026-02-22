
import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos'
import { webview } from '@kit.ArkWeb'
import { JsExecutorEngine } from 'js_executor_ohos'

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'
const SPLASH_MIN_DURATION = 1500
const SPLASH_MAX_DURATION = 5000
const SPLASH_FADE_DURATION = 500

@Entry(storage)
@Component
struct Index {
  private getAbilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }
  @LocalStorageLink('viewId') @Watch('onViewIdChanged') viewId: string = "";
  private jsWebController: webview.WebviewController = JsExecutorEngine.instance.getController()
  @State showSplash: boolean = true
  @State splashOpacity: number = 1
  @State iconScale: number = 0.8
  @State contentOpacity: number = 0
  private minTimerId: number = -1
  private maxTimerId: number = -1
  private minTimeReached: boolean = false
  private dismissed: boolean = false

  aboutToAppear(): void {
    // 入场动画
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.iconScale = 1
        this.contentOpacity = 1
      })
    }, 100)

    // 最短展示时间
    this.minTimerId = setTimeout(() => {
      this.minTimeReached = true
      if (this.viewId.length > 0) {
        this.dismissSplash()
      }
    }, SPLASH_MIN_DURATION)

    // 最长等待时间（安全兜底）
    this.maxTimerId = setTimeout(() => {
      this.dismissSplash()
    }, SPLASH_MAX_DURATION)
  }

  aboutToDisappear(): void {
    if (this.minTimerId !== -1) {
      clearTimeout(this.minTimerId)
      this.minTimerId = -1
    }
    if (this.maxTimerId !== -1) {
      clearTimeout(this.maxTimerId)
      this.maxTimerId = -1
    }
  }

  onViewIdChanged(): void {
    if (this.viewId.length > 0 && this.minTimeReached) {
      this.dismissSplash()
    }
  }

  private dismissSplash(): void {
    if (this.dismissed) {
      return
    }
    this.dismissed = true
    if (this.minTimerId !== -1) {
      clearTimeout(this.minTimerId)
      this.minTimerId = -1
    }
    if (this.maxTimerId !== -1) {
      clearTimeout(this.maxTimerId)
      this.maxTimerId = -1
    }
    this.getUIContext().animateTo({ duration: SPLASH_FADE_DURATION, curve: Curve.EaseOut, onFinish: () => {
      this.showSplash = false
    } }, () => {
      this.splashOpacity = 0
    })
  }

  build() {
    Stack() {
      FlutterPage({ viewId: this.viewId })

      // 隐藏的 Web 组件，用于执行 JS（斗鱼/抖音签名）
      Web({ src: 'about:blank', controller: this.jsWebController })
        .width(1)
        .height(1)
        .opacity(0)
        .position({ x: 0, y: 0 })
        .onPageEnd(() => {
          JsExecutorEngine.instance.onPageReady()
        })

      // 启动欢迎页
      if (this.showSplash) {
        Column() {
          Image($r('app.media.icon'))
            .width(120)
            .height(120)
            .borderRadius(24)
            .scale({ x: this.iconScale, y: this.iconScale })

          Text('Simple Live')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .margin({ top: 20 })
            .opacity(this.contentOpacity)

          Text('多平台直播聚合')
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.7)')
            .margin({ top: 8 })
            .opacity(this.contentOpacity)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .linearGradient({
          angle: 135,
          colors: [['#7C6DF0', 0], ['#4A7CF7', 0.5], ['#0984E3', 1]]
        })
        .opacity(this.splashOpacity)
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
  }

  onBackPress(): boolean {
    this.getAbilityContext().eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
