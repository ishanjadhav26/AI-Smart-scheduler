import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/event.dart';
import '../services/storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOP-LEVEL background callback — required by android_alarm_manager_plus
// Must NOT be inside any class. This runs in a separate isolate even when
// the app is completely swiped away from recent apps.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> alarmTopLevelCallback(int id) async {
  // Step 1: Initialize Flutter bindings in this background isolate
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Step 2: Initialize SharedPreferences storage
    await StorageService.init();

    // Step 3: Respect Focus Mode (user-set mute preference)
    if (StorageService.loadFocusMode()) return;

    // Step 4: Load saved events from disk
    final List<Event> events = StorageService.loadEvents();
    if (events.isEmpty) return;

    // Step 5: Find the event that this alarm corresponds to
    final bool isRepeat = (id & 0x40000000) != 0;
    Event? targetEvent;
    for (var ev in events) {
      if (AlarmService.computeAlarmId(ev.id, isRepeat) == id) {
        targetEvent = ev;
        break;
      }
    }

    if (targetEvent == null) return;

    final String title = targetEvent.title;
    final String timeStr =
        "${targetEvent.startTime.hour.toString().padLeft(2, '0')}:${targetEvent.startTime.minute.toString().padLeft(2, '0')}";
    final String bodyText = isRepeat
        ? "⏰ 5 MINUTES: $title starts at $timeStr. Join NOW!"
        : "⏰ 30 MINUTES: $title starts at $timeStr. Get ready!";

    // Step 6: Show high-priority heads-up notification (works 100% when app is closed)
    final FlutterLocalNotificationsPlugin notificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await notificationsPlugin.initialize(initSettings);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'smart_reminder_alarms',        // channel ID
      'Meeting Reminders',             // channel name
      channelDescription: 'High-priority meeting reminder calls',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,         // Shows over lock screen like an alarm
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    const NotificationDetails notifDetails =
        NotificationDetails(android: androidDetails);

    await notificationsPlugin.show(
      id,
      '📅 Meeting Reminder',
      bodyText,
      notifDetails,
    );

    // Step 7: Also speak via TTS (works when screen is on and audio available)
    try {
      final FlutterTts tts = FlutterTts();
      await tts.setLanguage("en-US");
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.setPitch(0.85);
      final alertText = "Meeting reminder. $title starts at $timeStr";
      await tts.speak(alertText);
      // Speak twice with a gap
      await Future.delayed(const Duration(seconds: 5));
      await tts.speak(alertText);
    } catch (ttsError) {
      debugPrint("TTS in background failed (notification shown instead): $ttsError");
    }
  } catch (e) {
    debugPrint("Background alarm callback error: $e");
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AlarmService — manages scheduling and cancellation of exact background alarms
// ─────────────────────────────────────────────────────────────────────────────
class AlarmService {
  // Initialize the alarm manager
  static Future<void> init() async {
    try {
      await AndroidAlarmManager.initialize();
    } catch (e) {
      debugPrint("AlarmService init error (non-Android?): $e");
    }
  }

  /// Schedule exact background alarms for all upcoming events.
  /// Call this after every: login, sync, add event, delete event, repeat set.
  static Future<void> scheduleReminders(List<Event> events) async {
    try {
      final now = DateTime.now();
      for (var ev in events) {
        if (ev.startTime.isBefore(now)) continue;

        // ── 30-minute reminder ──
        final trigger30 = ev.startTime.subtract(const Duration(minutes: 30));
        if (trigger30.isAfter(now)) {
          final int alarmId = computeAlarmId(ev.id, false);
          await AndroidAlarmManager.cancel(alarmId);
          await AndroidAlarmManager.oneShotAt(
            trigger30,
            alarmId,
            alarmTopLevelCallback,   // ← top-level function
            exact: true,
            wakeup: true,
            rescheduleOnReboot: true,
            allowWhileIdle: true,    // fires even in Doze mode
          );
          debugPrint("Scheduled 30-min alarm for '${ev.title}' at $trigger30 (id=$alarmId)");
        }

        // ── 5-minute repeat reminder (if user requested repeat call) ──
        if (ev.repeatScheduled) {
          final trigger5 = ev.startTime.subtract(const Duration(minutes: 5));
          if (trigger5.isAfter(now)) {
            final int alarmId = computeAlarmId(ev.id, true);
            await AndroidAlarmManager.cancel(alarmId);
            await AndroidAlarmManager.oneShotAt(
              trigger5,
              alarmId,
              alarmTopLevelCallback,  // ← top-level function
              exact: true,
              wakeup: true,
              rescheduleOnReboot: true,
              allowWhileIdle: true,
            );
            debugPrint("Scheduled 5-min alarm for '${ev.title}' at $trigger5 (id=$alarmId)");
          }
        }
      }
    } catch (e) {
      debugPrint("Failed to schedule reminders: $e");
    }
  }

  /// Cancel both alarms for a specific event
  static Future<void> cancelReminder(String eventId, bool isRepeat) async {
    try {
      await AndroidAlarmManager.cancel(computeAlarmId(eventId, isRepeat));
    } catch (e) {
      debugPrint("Failed to cancel alarm: $e");
    }
  }

  /// Deterministically converts a string event ID into a unique positive int alarm ID.
  /// Repeat alarms use a different bit pattern so they never clash with 30-min alarms.
  static int computeAlarmId(String eventId, bool isRepeat) {
    final int base = eventId.hashCode & 0x3FFFFFFF;
    return isRepeat ? (base | 0x40000000) : base;
  }
}
