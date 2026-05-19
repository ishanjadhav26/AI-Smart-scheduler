import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';
import 'providers/app_provider.dart';
import 'services/storage_service.dart';
import 'services/tts_service.dart';
import 'services/alarm_service.dart';

void main() async {
  // 1. Ensure Flutter bindings are fully established on boot
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize SharedPreferences cache service
  await StorageService.init();

  // 3. Initialize robotic voice TTS speech alerts
  await TtsService.init();

  // 4. Initialize notification channel (required for background notifications)
  await _initNotifications();

  // 5. Initialize background alarm reminder service
  await AlarmService.init();

  // 6. Instantiate provider state
  final appProvider = AppProvider();
  await appProvider.init();

  // 7. Launch application
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ],
      child: const SmartReminderApp(),
    ),
  );
}

/// Creates the Android notification channel that all alarm notifications
/// will be posted to. Must be created before any notification is shown.
Future<void> _initNotifications() async {
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  await plugin.initialize(initSettings);

  // Create the high-importance channel for meeting alarms
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'smart_reminder_alarms',
    'Meeting Reminders',
    description: 'High-priority meeting reminder calls',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}
