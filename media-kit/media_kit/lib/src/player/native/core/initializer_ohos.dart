/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:collection';
import 'dart:ffi';

import 'package:media_kit/ffi/ffi.dart';
import 'package:media_kit/generated/libmpv/bindings.dart' as generated;
import 'package:synchronized/synchronized.dart';

/// {@template initializer_ohos}
///
/// InitializerOhos
/// ---------------
/// HarmonyOS-specific initializer that uses Timer-based polling instead of
/// wakeup callbacks, since NativeCallable wakeup mechanism doesn't work on HarmonyOS.
///
/// {@endtemplate}
class InitializerOhos {
  /// Singleton instance.
  static InitializerOhos? _instance;

  /// {@macro initializer_ohos}
  InitializerOhos._(this.mpv);

  /// {@macro initializer_ohos}
  factory InitializerOhos(generated.MPV mpv) {
    _instance ??= InitializerOhos._(mpv);
    return _instance!;
  }

  /// Generated libmpv C API bindings.
  final generated.MPV mpv;

  /// Creates [Pointer<mpv_handle>].
  Future<Pointer<generated.mpv_handle>> create(
    Future<void> Function(Pointer<generated.mpv_event>) callback, {
    Map<String, String> options = const {},
  }) async {
    Pointer<generated.mpv_handle> ctx;
    try {
      ctx = mpv.mpv_create();
    } catch (e, stack) {
      print('[InitializerOhos] mpv_create() 异常: $e');
      print('[InitializerOhos] ���栈: $stack');
      rethrow;
    }

    // Set options
    for (final entry in options.entries) {
      final name = entry.key.toNativeUtf8();
      final value = entry.value.toNativeUtf8();
      mpv.mpv_set_option_string(ctx, name.cast(), value.cast());
      calloc.free(name);
      calloc.free(value);
    }

    // Initialize mpv
    final initResult = mpv.mpv_initialize(ctx);
    if (initResult < 0) {
      final error = mpv.mpv_error_string(initResult).cast<Utf8>().toDartString();
      print('[InitializerOhos] mpv_initialize 失败: $error');
      throw Exception('mpv_initialize failed: $error');
    }

    // Store callback and lock
    _locks[ctx.address] = Lock();
    _eventCallbacks[ctx.address] = callback;

    // Start polling timer (poll every 16ms ≈ 60fps)
    final timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _pollEvents(ctx);
    });
    _timers[ctx.address] = timer;

    print('[InitializerOhos] mpv 初始化完成, ctx=${ctx.address}');
    return ctx;
  }

  /// Disposes [Pointer<mpv_handle>].
  void dispose(Pointer<generated.mpv_handle> ctx) {
    // Stop timer
    _timers.remove(ctx.address)?.cancel();

    // Clean up
    _locks.remove(ctx.address);
    _eventCallbacks.remove(ctx.address);
  }

  /// Polls for events from mpv.
  void _pollEvents(Pointer<generated.mpv_handle> ctx) {
    _locks[ctx.address]?.synchronized(() async {
      while (true) {
        // Poll with 0 timeout (non-blocking)
        final event = mpv.mpv_wait_event(ctx, 0);
        if (event == nullptr) return;
        if (event.ref.event_id == generated.mpv_event_id.MPV_EVENT_NONE) return;

        // Process event
        await _eventCallbacks[ctx.address]?.call(event);
      }
    });
  }

  final _locks = HashMap<int, Lock>();
  final _eventCallbacks = HashMap<int, Future<void> Function(Pointer<generated.mpv_event>)>();
  final _timers = HashMap<int, Timer>();
}
