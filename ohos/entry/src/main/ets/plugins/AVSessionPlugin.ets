import {
  AbilityAware,
  AbilityPluginBinding,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  EventChannel,
  StreamHandler,
  EventSink,
} from '@ohos/flutter_ohos';
import { avSession as AVSessionManager } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, WantAgent, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AVSessionPlugin';
const DOMAIN = 0xFF01;
const METHOD_CHANNEL = 'com.simplelive/avsession';
const EVENT_CHANNEL = 'com.simplelive/avsession_events';

function logI(msg: string): void {
  hilog.info(DOMAIN, TAG, '%{public}s', msg);
}

function logE(msg: string): void {
  hilog.error(DOMAIN, TAG, '%{public}s', msg);
}

function logW(msg: string): void {
  hilog.warn(DOMAIN, TAG, '%{public}s', msg);
}

export default class AVSessionPlugin implements FlutterPlugin, AbilityAware, MethodCallHandler, StreamHandler {
  private context: common.UIAbilityContext | null = null;
  private session: AVSessionManager.AVSession | null = null;
  private methodChannel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  private eventSink: EventSink | null = null;
  private isBackgroundRunning: boolean = false;

  getUniqueClassName(): string {
    return 'AVSessionPlugin';
  }

  // ==================== FlutterPlugin ====================

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.methodChannel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
    this.methodChannel.setMethodCallHandler(this);

    this.eventChannel = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL);
    this.eventChannel.setStreamHandler(this);

    logI('AVSessionPlugin attached to engine');
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.methodChannel?.setMethodCallHandler(null);
    this.methodChannel = null;
    this.eventChannel?.setStreamHandler(null);
    this.eventChannel = null;
    this.destroySession().catch((e: Error) => {
      logW('destroySession in onDetachedFromEngine failed: ' + e.message);
    });
    logI('AVSessionPlugin detached from engine');
  }

  // ==================== AbilityAware ====================

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.context = binding.getAbility().context as common.UIAbilityContext;
    logI('onAttachedToAbility, context acquired');
  }

  onDetachedFromAbility(): void {
    const ctx = this.context;
    this.context = null;
    this.destroySessionWithContext(ctx).catch((e: Error) => {
      logW('destroySession in onDetachedFromAbility failed: ' + e.message);
    });
  }

  // ==================== StreamHandler ====================

  onListen(args: Object, events: EventSink): void {
    this.eventSink = events;
    logI('EventChannel listener registered');
  }

  onCancel(args: Object): void {
    this.eventSink = null;
    logI('EventChannel listener cancelled');
  }

  // ==================== MethodCallHandler ====================

  onMethodCall(call: MethodCall, result: MethodResult): void {
    logI('onMethodCall: ' + call.method);
    switch (call.method) {
      case 'activate':
        this.handleActivate(call, result);
        break;
      case 'updateMetadata':
        this.handleUpdateMetadata(call, result);
        break;
      case 'updatePlaybackState':
        this.handleUpdatePlaybackState(call, result);
        break;
      case 'deactivate':
        this.handleDeactivate(result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  // ==================== activate ====================

  private async handleActivate(call: MethodCall, result: MethodResult): Promise<void> {
    if (this.context == null) {
      logE('activate failed: context is null');
      result.error('NO_CONTEXT', 'Context is null', null);
      return;
    }
    try {
      // 清理可能存在的旧 session
      if (this.session != null) {
        logI('Cleaning up previous session before activate');
        await this.destroySession();
      }

      logI('Creating AVSession...');
      this.session = await AVSessionManager.createAVSession(
        this.context, 'SimpleLive', 'audio'
      );
      logI('AVSession created successfully');

      // 设置初始元数据
      const title: string = (call.argument('title') as string) ?? 'SimpleLive';
      const artist: string = (call.argument('artist') as string) ?? '';
      const mediaImage: string = (call.argument('mediaImage') as string) ?? '';
      const assetId: string = (call.argument('assetId') as string) ?? '0';

      const metadata: AVSessionManager.AVMetadata = {
        assetId: assetId,
        title: title,
        artist: artist,
        mediaImage: mediaImage,
      };
      await this.session.setAVMetadata(metadata);
      logI('Metadata set: ' + title + ' - ' + artist);

      // 设置初始播放状态
      const playbackState: AVSessionManager.AVPlaybackState = {
        state: AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY,
      };
      await this.session.setAVPlaybackState(playbackState);
      logI('PlaybackState set to PLAY');

      // 注册系统播控命令监听
      this.registerSessionListeners();

      // 激活会话
      await this.session.activate();
      logI('AVSession activated');

      // 启动长时任务
      await this.startBackgroundRunning();

      result.success(null);
      logI('activate completed successfully');
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      const code = (e as BusinessError)?.code;
      logE('Activate failed: code=' + code + ', msg=' + msg);
      result.error(String(code ?? 'UNKNOWN'), msg, null);
    }
  }

  // ==================== updateMetadata ====================

  private async handleUpdateMetadata(call: MethodCall, result: MethodResult): Promise<void> {
    if (this.session == null) {
      result.error('NO_SESSION', 'AVSession not created', null);
      return;
    }
    try {
      const metadata: AVSessionManager.AVMetadata = {
        assetId: (call.argument('assetId') as string) ?? '0',
        title: (call.argument('title') as string) ?? '',
        artist: (call.argument('artist') as string) ?? '',
        mediaImage: (call.argument('mediaImage') as string) ?? '',
      };
      await this.session.setAVMetadata(metadata);
      result.success(null);
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      logE('updateMetadata failed: ' + msg);
      result.error('UPDATE_META_ERROR', msg, null);
    }
  }

  // ==================== updatePlaybackState ====================

  private async handleUpdatePlaybackState(call: MethodCall, result: MethodResult): Promise<void> {
    if (this.session == null) {
      result.error('NO_SESSION', 'AVSession not created', null);
      return;
    }
    try {
      const stateValue: number = (call.argument('state') as number) ?? 0;
      const stateNames: string[] = ['PLAY', 'PAUSE', 'STOP'];
      logI('updatePlaybackState: state=' + stateValue + ' (' + (stateNames[stateValue] ?? 'UNKNOWN') + ')');
      let avState: AVSessionManager.PlaybackState;
      if (stateValue === 1) {
        avState = AVSessionManager.PlaybackState.PLAYBACK_STATE_PAUSE;
      } else if (stateValue === 2) {
        avState = AVSessionManager.PlaybackState.PLAYBACK_STATE_STOP;
      } else {
        avState = AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY;
      }
      const playbackState: AVSessionManager.AVPlaybackState = {
        state: avState,
      };
      await this.session.setAVPlaybackState(playbackState);
      result.success(null);
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      logE('updatePlaybackState failed: ' + msg);
      result.error('UPDATE_STATE_ERROR', msg, null);
    }
  }

  // ==================== deactivate ====================

  private async handleDeactivate(result: MethodResult): Promise<void> {
    try {
      await this.destroySession();
      result.success(null);
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      logE('deactivate failed: ' + msg);
      result.error('DEACTIVATE_ERROR', msg, null);
    }
  }

  // ==================== 系统播控命令监听 ====================

  private registerSessionListeners(): void {
    if (this.session == null) return;

    try {
      this.session.on('play', () => {
        logI('System command: play');
        this.sendEventToDart('play');
        this.session?.setAVPlaybackState({
          state: AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY,
        }).catch((e: Error) => {
          logW('setAVPlaybackState(PLAY) failed: ' + e.message);
        });
      });
    } catch (e) {
      logW('Failed to register play listener: ' + ((e instanceof Error) ? e.message : String(e)));
    }

    try {
      this.session.on('pause', () => {
        logI('System command: pause');
        this.sendEventToDart('pause');
        this.session?.setAVPlaybackState({
          state: AVSessionManager.PlaybackState.PLAYBACK_STATE_PAUSE,
        }).catch((e: Error) => {
          logW('setAVPlaybackState(PAUSE) failed: ' + e.message);
        });
      });
    } catch (e) {
      logW('Failed to register pause listener: ' + ((e instanceof Error) ? e.message : String(e)));
    }

    try {
      this.session.on('stop', () => {
        logI('System command: stop');
        this.sendEventToDart('stop');
        this.destroySession().catch((e: Error) => {
          logW('destroySession in stop callback failed: ' + e.message);
        });
      });
    } catch (e) {
      logW('Failed to register stop listener: ' + ((e instanceof Error) ? e.message : String(e)));
    }

    logI('Session listeners registered (play/pause/stop)');
  }

  private sendEventToDart(event: string): void {
    if (this.eventSink != null) {
      this.eventSink.success(event);
    } else {
      logW('EventSink is null, cannot send event: ' + event);
    }
  }

  // ==================== 长时任务管理 ====================

  private async startBackgroundRunning(): Promise<void> {
    if (this.context == null || this.isBackgroundRunning) {
      logW('startBackgroundRunning skipped: context=' + (this.context != null) + ', already=' + this.isBackgroundRunning);
      return;
    }
    try {
      logI('Building WantAgent...');
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: 'com.yabizzh.simplelive',
            abilityName: 'EntryAbility',
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
      };
      const agent: WantAgent = await wantAgent.getWantAgent(wantAgentInfo);
      logI('WantAgent created, starting background running...');

      await backgroundTaskManager.startBackgroundRunning(
        this.context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        agent
      );
      this.isBackgroundRunning = true;
      logI('Background running started successfully');
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      const code = (e as BusinessError)?.code;
      logE('startBackgroundRunning failed: code=' + code + ', msg=' + msg);
    }
  }

  private async stopBackgroundRunning(ctx?: common.UIAbilityContext | null): Promise<void> {
    const context = ctx ?? this.context;
    if (context == null || !this.isBackgroundRunning) return;
    try {
      await backgroundTaskManager.stopBackgroundRunning(context);
      this.isBackgroundRunning = false;
      logI('Background running stopped');
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      logW('stopBackgroundRunning failed: ' + msg);
    }
  }

  // ==================== 销毁清理 ====================

  private async destroySession(): Promise<void> {
    await this.destroySessionWithContext(this.context);
  }

  private async destroySessionWithContext(ctx: common.UIAbilityContext | null): Promise<void> {
    try {
      if (this.session != null) {
        this.session.off('play');
        this.session.off('pause');
        this.session.off('stop');
        await this.session.deactivate();
        await this.session.destroy();
        this.session = null;
        logI('AVSession destroyed');
      }
      await this.stopBackgroundRunning(ctx);
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      logW('destroySession error: ' + msg);
    }
  }
}
