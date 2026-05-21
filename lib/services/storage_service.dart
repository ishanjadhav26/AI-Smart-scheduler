import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../models/user.dart';

class StorageService {
  static late SharedPreferences _prefs;

  // Initialize SharedPreferences on application boot
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Save cached events
  static Future<void> saveEvents(List<Event> events) async {
    final data = events.map((e) => e.toJson()).toList();
    await _prefs.setString('sra_events', jsonEncode(data));
  }

  // Load cached events
  static List<Event> loadEvents() {
    final raw = _prefs.getString('sra_events');
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  // Save user info
  static Future<void> saveUser(User? user) async {
    if (user == null) {
      await _prefs.remove('sra_user');
    } else {
      await _prefs.setString('sra_user', jsonEncode(user.toJson()));
    }
  }

  // Load user info
  static User? loadUser() {
    final raw = _prefs.getString('sra_user');
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // Save OAuth Tokens
  static Future<void> saveOAuthToken(String? token, int? expiryMs) async {
    if (token == null) {
      await _prefs.remove('sra_access_token');
      await _prefs.remove('sra_token_expiry');
    } else {
      await _prefs.setString('sra_access_token', token);
      await _prefs.setInt('sra_token_expiry', expiryMs ?? 0);
    }
  }

  static String? loadAccessToken() {
    return _prefs.getString('sra_access_token');
  }

  static int? loadTokenExpiry() {
    return _prefs.getInt('sra_token_expiry');
  }

  // Focus Mode
  static Future<void> saveFocusMode(bool enabled) async {
    await _prefs.setBool('sra_focus_mode', enabled);
  }

  static bool loadFocusMode() {
    return _prefs.getBool('sra_focus_mode') ?? false;
  }

  // Last Sync timestamp
  static Future<void> saveLastSync(DateTime? time) async {
    if (time == null) {
      await _prefs.remove('sra_last_sync');
    } else {
      await _prefs.setString('sra_last_sync', time.toIso8601String());
    }
  }

  static DateTime? loadLastSync() {
    final raw = _prefs.getString('sra_last_sync');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // Complete local sign out reset
  static Future<void> clearAll() async {
    await _prefs.clear();
  }

  // Pending reminder call state from notification actions/taps.
  static Future<void> savePendingCall(String eventId, bool isRepeat) async {
    await _prefs.setString('sra_pending_call_event_id', eventId);
    await _prefs.setBool('sra_pending_call_is_repeat', isRepeat);
  }

  static Map<String, dynamic>? loadPendingCall() {
    final eventId = _prefs.getString('sra_pending_call_event_id');
    if (eventId == null || eventId.isEmpty) return null;
    final isRepeat = _prefs.getBool('sra_pending_call_is_repeat') ?? false;
    return {'eventId': eventId, 'isRepeat': isRepeat};
  }

  static Future<void> clearPendingCall() async {
    await _prefs.remove('sra_pending_call_event_id');
    await _prefs.remove('sra_pending_call_is_repeat');
  }

  static String _ackKey(String eventId, bool isRepeat) =>
      'sra_call_ack_${isRepeat ? 'r' : 'n'}_$eventId';

  static Future<void> saveCallAcknowledged(String eventId, bool isRepeat) async {
    await _prefs.setBool(_ackKey(eventId, isRepeat), true);
  }

  static bool isCallAcknowledged(String eventId, bool isRepeat) {
    return _prefs.getBool(_ackKey(eventId, isRepeat)) ?? false;
  }

  static Future<void> clearCallAcknowledged(String eventId, bool isRepeat) async {
    await _prefs.remove(_ackKey(eventId, isRepeat));
  }
}
