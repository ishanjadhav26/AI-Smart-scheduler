import 'package:flutter/services.dart';
import '../models/event.dart';

class NativeAlarmBridge {
  static const MethodChannel _channel =
      MethodChannel('smart_reminder/native_alarm');

  static Future<void> scheduleReminder(
    Event event,
    bool isRepeat,
    DateTime triggerAt,
  ) async {
    await _channel.invokeMethod('scheduleReminder', {
      'eventId': event.id,
      'title': event.title,
      'timeText':
          '${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')}',
      'triggerAtMs': triggerAt.millisecondsSinceEpoch,
      'isRepeat': isRepeat,
    });
  }

  static Future<void> cancelReminder(String eventId, bool isRepeat) async {
    await _channel.invokeMethod('cancelReminder', {
      'eventId': eventId,
      'isRepeat': isRepeat,
    });
  }

  static Future<void> startCalendarWatcher() async {
    await _channel.invokeMethod('startCalendarWatcher');
  }
}
