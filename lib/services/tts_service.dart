import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _isPlaying = false;
  static Timer? _loopTimer;

  // Initialize speaking rates
  static Future<void> init() async {
    // Standard lower-pitch authoritative robotic settings
    await _tts.setPitch(0.85); // slightly lower pitch for robotic effect
    await _tts.setSpeechRate(0.48); // slightly slower pace for clear alarm effect
    await _tts.setVolume(1.0);
    
    // Set language
    await _tts.setLanguage("en-US");
  }

  // Announces robotic alarms exactly 3 times with a space gap
  static Future<void> speakMeetingAlert(String title, String formattedTime) async {
    if (_isPlaying) return;
    _isPlaying = true;

    final alertText = "You have a meeting: $title at $formattedTime";
    int repeatCount = 0;

    Future<void> runAnnouncement() async {
      if (!_isPlaying) return;
      
      await _tts.speak(alertText);
      repeatCount++;
      
      if (repeatCount < 3 && _isPlaying) {
        // Wait 6 seconds (mechanical delay spacing) before speaking again
        _loopTimer = Timer(const Duration(seconds: 6), () {
          runAnnouncement();
        });
      } else {
        _isPlaying = false;
      }
    }

    await runAnnouncement();
  }

  // Instantly halts speech and loop cycles
  static Future<void> stopSpeech() async {
    _isPlaying = false;
    _loopTimer?.cancel();
    await _tts.stop();
  }
}
