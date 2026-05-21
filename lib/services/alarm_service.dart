import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/event.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/native_alarm_bridge.dart';

@pragma('vm:entry-point')
Future<void> syncTaskCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await StorageService.init();

    final authResult = await AuthService.signInSilently();
    String? token;

    if (authResult != null) {
      token = authResult['accessToken'] as String?;
      final user = authResult['user'];
      await StorageService.saveOAuthToken(
        token,
        DateTime.now().millisecondsSinceEpoch + 3600 * 1000,
      );
      if (user != null) {
        await StorageService.saveUser(user);
      }
    } else {
      token = StorageService.loadAccessToken();
    }

    if (token != null) {
      final events = await ApiService.fetchEvents(token);
      await StorageService.saveEvents(events);
      await StorageService.saveLastSync(DateTime.now());
      await AlarmService.scheduleReminders(events);
      debugPrint('Background auto-sync successful.');
    }
  } catch (e) {
    debugPrint('Background auto-sync failed: $e');
  }
}

@pragma('vm:entry-point')
Future<void> alarmTopLevelCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await StorageService.init();

    if (StorageService.loadFocusMode()) return;

    final events = StorageService.loadEvents();
    if (events.isEmpty) return;

    final isRepeat = AlarmService.isRepeatFromAlarmId(id);
    final stage = AlarmService.stageFromAlarmId(id);

    Event? targetEvent;
    for (final ev in events) {
      if (AlarmService.computeAlarmId(ev.id, isRepeat, stage: 0) ==
          AlarmService.primaryAlarmId(id)) {
        targetEvent = ev;
        break;
      }
    }

    if (targetEvent == null) return;
    if (StorageService.isCallAcknowledged(targetEvent.id, isRepeat)) return;

    final title = targetEvent.title;
    final timeStr =
        '${targetEvent.startTime.hour.toString().padLeft(2, '0')}:${targetEvent.startTime.minute.toString().padLeft(2, '0')}';
    final bodyText = isRepeat
        ? '5 MINUTES: $title starts at $timeStr. Join now.'
        : '30 MINUTES: $title starts at $timeStr. Get ready.';

    final notificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await notificationsPlugin.initialize(initSettings);

    const androidDetails = AndroidNotificationDetails(
      'smart_reminder_alarms',
      'Meeting Reminders',
      channelDescription: 'High-priority meeting reminder calls',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: true,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      styleInformation: BigTextStyleInformation(''),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'accept_call',
          'Accept',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'decline_call',
          'Decline',
          cancelNotification: true,
        ),
      ],
    );

    const notifDetails = NotificationDetails(android: androidDetails);

    const alarmChannel = AndroidNotificationChannel(
      'smart_reminder_alarms',
      'Meeting Reminders',
      description: 'High-priority meeting reminder calls',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
    );
    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alarmChannel);

    await notificationsPlugin.show(
      id,
      'Incoming Meeting Call',
      bodyText,
      notifDetails,
      payload: '${targetEvent.id}|${isRepeat ? '1' : '0'}',
    );

    if (stage < 2 && !StorageService.isCallAcknowledged(targetEvent.id, isRepeat)) {
      final nextStage = stage + 1;
      final retryId = AlarmService.computeAlarmId(
        targetEvent.id,
        isRepeat,
        stage: nextStage,
      );
      await AndroidAlarmManager.cancel(retryId);
      await AndroidAlarmManager.oneShot(
        const Duration(seconds: 20),
        retryId,
        alarmTopLevelCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
      );
    }

    try {
      final tts = FlutterTts();
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.setPitch(0.85);
      await tts.speak('Meeting reminder. $title starts at $timeStr');
    } catch (ttsError) {
      debugPrint('TTS in background failed: $ttsError');
    }
  } catch (e) {
    debugPrint('Background alarm callback error: $e');
  }
}

class AlarmService {
  static const int _repeatBit = 0x40000000;
  static const int _stageMask = 0x0C000000;
  static const int _stageShift = 26;
  static const int _baseMask = 0x03FFFFFF;

  static Future<void> init() async {
    try {
      await AndroidAlarmManager.initialize();
      await scheduleBackgroundSync();
    } catch (e) {
      debugPrint('AlarmService init error (non-Android?): $e');
    }
  }

  static Future<void> scheduleBackgroundSync() async {
    try {
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 15),
        999,
        syncTaskCallback,
        exact: false,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      debugPrint('Scheduled background auto-sync every 15 mins.');
    } catch (e) {
      debugPrint('Failed to schedule background sync: $e');
    }
  }

  static Future<void> scheduleReminders(List<Event> events) async {
    try {
      final now = DateTime.now();
      for (final ev in events) {
        if (ev.startTime.isBefore(now)) continue;

        await StorageService.clearCallAcknowledged(ev.id, false);
        final trigger30 = ev.startTime.subtract(const Duration(minutes: 30));
        if (trigger30.isAfter(now)) {
          final alarmId = computeAlarmId(ev.id, false, stage: 0);
          try {
            await NativeAlarmBridge.scheduleReminder(ev, false, trigger30);
          } catch (_) {}
          await AndroidAlarmManager.cancel(alarmId);
          await AndroidAlarmManager.cancel(computeAlarmId(ev.id, false, stage: 1));
          await AndroidAlarmManager.cancel(computeAlarmId(ev.id, false, stage: 2));
          await AndroidAlarmManager.oneShotAt(
            trigger30,
            alarmId,
            alarmTopLevelCallback,
            exact: true,
            wakeup: true,
            rescheduleOnReboot: true,
            allowWhileIdle: true,
          );
          debugPrint("Scheduled 30-min alarm for '${ev.title}' at $trigger30 (id=$alarmId)");
        }

        if (ev.repeatScheduled) {
          await StorageService.clearCallAcknowledged(ev.id, true);
          final trigger5 = ev.startTime.subtract(const Duration(minutes: 5));
          if (trigger5.isAfter(now)) {
            final alarmId = computeAlarmId(ev.id, true, stage: 0);
            try {
              await NativeAlarmBridge.scheduleReminder(ev, true, trigger5);
            } catch (_) {}
            await AndroidAlarmManager.cancel(alarmId);
            await AndroidAlarmManager.cancel(computeAlarmId(ev.id, true, stage: 1));
            await AndroidAlarmManager.cancel(computeAlarmId(ev.id, true, stage: 2));
            await AndroidAlarmManager.oneShotAt(
              trigger5,
              alarmId,
              alarmTopLevelCallback,
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
      debugPrint('Failed to schedule reminders: $e');
    }
  }

  static Future<void> cancelReminder(String eventId, bool isRepeat) async {
    try {
      try {
        await NativeAlarmBridge.cancelReminder(eventId, isRepeat);
      } catch (_) {}
      await AndroidAlarmManager.cancel(computeAlarmId(eventId, isRepeat, stage: 0));
      await AndroidAlarmManager.cancel(computeAlarmId(eventId, isRepeat, stage: 1));
      await AndroidAlarmManager.cancel(computeAlarmId(eventId, isRepeat, stage: 2));
      await StorageService.clearCallAcknowledged(eventId, isRepeat);
    } catch (e) {
      debugPrint('Failed to cancel alarm: $e');
    }
  }

  static int computeAlarmId(String eventId, bool isRepeat, {int stage = 0}) {
    int hash = 0x811C9DC5;
    for (final unit in eventId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    final base = hash & _baseMask;
    final normalizedStage = stage.clamp(0, 2).toInt();
    final stageBits = normalizedStage << _stageShift;
    return base | stageBits | (isRepeat ? _repeatBit : 0);
  }

  static bool isRepeatFromAlarmId(int id) => (id & _repeatBit) != 0;

  static int stageFromAlarmId(int id) => (id & _stageMask) >> _stageShift;

  static int primaryAlarmId(int id) => id & ~_stageMask;
}
