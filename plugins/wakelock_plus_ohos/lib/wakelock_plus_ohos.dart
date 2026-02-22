import 'dart:async';
import 'package:flutter/services.dart';

/// Messages for toggling and querying the wakelock state.
class ToggleMessage {
  final bool enable;
  ToggleMessage(this.enable);

  Object encode() => <Object?>[enable];

  static ToggleMessage decode(Object message) {
    final list = message as List<Object?>;
    return ToggleMessage(list[0]! as bool);
  }
}

class IsEnabledMessage {
  final bool enabled;
  IsEnabledMessage(this.enabled);

  Object encode() => <Object?>[enabled];

  static IsEnabledMessage decode(Object message) {
    final list = message as List<Object?>;
    return IsEnabledMessage(list[0]! as bool);
  }
}

class _WakelockApiCodec extends StandardMessageCodec {
  const _WakelockApiCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is ToggleMessage) {
      buffer.putUint8(129);
      writeValue(buffer, value.encode());
    } else if (value is IsEnabledMessage) {
      buffer.putUint8(128);
      writeValue(buffer, value.encode());
    } else {
      super.writeValue(buffer, value);
    }
  }

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    switch (type) {
      case 128:
        return IsEnabledMessage.decode(readValue(buffer)!);
      case 129:
        return ToggleMessage.decode(readValue(buffer)!);
      default:
        return super.readValueOfType(type, buffer);
    }
  }
}

/// API for controlling wakelock on OpenHarmony.
class WakelockPlusOhos {
  static const MessageCodec<Object?> codec = _WakelockApiCodec();

  static const BasicMessageChannel<Object?> _toggleChannel =
      BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    codec,
  );

  static const BasicMessageChannel<Object?> _isEnabledChannel =
      BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.isEnabled',
    codec,
  );

  /// Enable or disable wakelock.
  static Future<void> toggle({required bool enable}) async {
    final reply = await _toggleChannel.send(<Object?>[ToggleMessage(enable)]);
    if (reply is List && reply.isNotEmpty && reply[0] != null) {
      throw PlatformException(
        code: reply[0].toString(),
        message: reply.length > 1 ? reply[1]?.toString() : null,
        details: reply.length > 2 ? reply[2] : null,
      );
    }
  }

  /// Check if wakelock is enabled.
  static Future<bool> get enabled async {
    final reply = await _isEnabledChannel.send(null);
    if (reply is List && reply.isNotEmpty) {
      if (reply[0] is IsEnabledMessage) {
        return (reply[0] as IsEnabledMessage).enabled;
      } else {
        throw PlatformException(
          code: reply[0].toString(),
          message: reply.length > 1 ? reply[1]?.toString() : null,
          details: reply.length > 2 ? reply[2] : null,
        );
      }
    }
    return false;
  }
}
