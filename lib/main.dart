import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  // 3b. Initialize background alarm reminder service
  await AlarmService.init();

  // 4. Instantiate provider state
  final appProvider = AppProvider();
  await appProvider.init();

  // 5. Launch application
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ],
      child: const SmartReminderApp(),
    ),
  );
}
