import 'dart:async';
import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../models/event.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';

class AlarmService {
  // Initialize background alarm scheduler
  static Future<void> init() async {
    try {
      await AndroidAlarmManager.initialize();
    } catch (e) {
      debugPrint("Alarm Service initialization error (running on non-Android platform): $e");
    }
  }

  // Refreshes exact background alarms for all upcoming events
  static Future<void> scheduleReminders(List<Event> events) async {
    try {
      final now = DateTime.now();
      for (var ev in events) {
        // Skip completed events
        if (ev.startTime.isBefore(now)) continue;

        // 1. Schedule 30-minute reminder call
        final trigger30Time = ev.startTime.subtract(const Duration(minutes: 30));
        if (trigger30Time.isAfter(now)) {
          final int alarmId = _getAlarmId(ev.id, false);
          
          // Clear any stale alarm with this ID
          await AndroidAlarmManager.cancel(alarmId);
          
          // Schedule precision exact alarm that bypasses power saving modes (Doze mode)
          await AndroidAlarmManager.oneShotAt(
            trigger30Time,
            alarmId,
            alarmCallback,
            exact: true,
            wakeup: true,
            rescheduleOnReboot: true,
          );
        }

        // 2. Schedule 5-minute repeat reminder call (if configured)
        if (ev.repeatScheduled) {
          final trigger5Time = ev.startTime.subtract(const Duration(minutes: 5));
          if (trigger5Time.isAfter(now)) {
            final int alarmId = _getAlarmId(ev.id, true);
            
            await AndroidAlarmManager.cancel(alarmId);
            
            await AndroidAlarmManager.oneShotAt(
              trigger5Time,
              alarmId,
              alarmCallback,
              exact: true,
              wakeup: true,
              rescheduleOnReboot: true,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Failed to schedule background alarms: $e");
    }
  }

  // Cancels a scheduled alarm
  static Future<void> cancelReminder(String eventId, bool isRepeat) async {
    try {
      final int alarmId = _getAlarmId(eventId, isRepeat);
      await AndroidAlarmManager.cancel(alarmId);
    } catch (e) {
      debugPrint("Failed to cancel alarm: $e");
    }
  }

  // Generates unique positive integer from string ID
  static int _getAlarmId(String eventId, bool isRepeat) {
    final int baseHash = eventId.hashCode & 0x3FFFFFFF; // 30 bits positive int
    return isRepeat ? (baseHash | 0x40000000) : baseHash;
  }

  // Background Isolate Callback executed exactly at the trigger time, even when the app is closed!
  @pragma('vm:entry-point')
  static void alarmCallback(int id) async {
    // 1. Initialize background Flutter engine bindings
    WidgetsFlutterBinding.ensureInitialized();

    try {
      // 2. Load disk storage state
      await StorageService.init();

      // 3. Skip if user enabled Focus Mode (mute state)
      if (StorageService.loadFocusMode()) return;

      // 4. Retrieve stored meetings database
      final List<Event> events = StorageService.loadEvents();
      if (events.isEmpty) return;

      // 5. Look up matching event title & time range
      Event? targetEvent;
      final bool isRepeat = (id & 0x40000000) != 0;

      for (var ev in events) {
        if (_getAlarmId(ev.id, isRepeat) == id) {
          targetEvent = ev;
          break;
        }
      }

      if (targetEvent != null) {
        // 6. Initialize Text-to-Speech engine in isolate context
        await TtsService.init();

        final String timeStr = "${targetEvent.startTime.hour.toString().padLeft(2, '0')}:${targetEvent.startTime.minute.toString().padLeft(2, '0')}";
        
        // 7. Fire robotic alarm voice TTS alerts 3 consecutive times with spacing gaps
        await TtsService.speakMeetingAlert(targetEvent.title, timeStr);
      }
    } catch (e) {
      debugPrint("Error in background alarm isolate callback: $e");
    }
  }
}
