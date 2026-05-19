import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/call_screen.dart';

class SmartReminderApp extends StatelessWidget {
  const SmartReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Reminder Scheduler',
      debugShowCheckedModeBanner: false,
      
      // Premium Black Glow Space theme
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030008),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFA78BFA), // glow purple
          secondary: Color(0xFF38BDF8), // space blue
          surface: Color(0xFF0F091A),
          background: Color(0xFF030008),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white, fontSize: 14),
          bodyMedium: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
      
      home: Consumer<AppProvider>(
        builder: (ctx, provider, child) {
          // If not signed in, show GSI splash landing
          if (provider.accessToken == null) {
            return const LoginScreen();
          }

          // Otherwise show dashboard, with simulated call overlay stacked globally
          return Stack(
            children: [
              const DashboardScreen(),
              if (provider.currentCall != null)
                const CallScreen(),
            ],
          );
        },
      ),
    );
  }
}
