import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import '../services/auth_service.dart';
import '../services/alarm_service.dart';

class AppProvider with ChangeNotifier {
  User? _user;
  String? _accessToken;
  int? _tokenExpiry;
  List<Event> _events = [];
  bool _focusMode = false;
  DateTime? _lastSync;
  String _activeTab = 'overview'; // 'overview' | 'history' | 'add-event' | 'settings'
  
  Event? _currentCall;
  bool _isRepeatCall = false;
  bool _isSyncing = false;
  
  Timer? _checkTimer;
  Timer? _autoSyncTimer;

  // Getters
  User? get user => _user;
  String? get accessToken => _accessToken;
  List<Event> get events => _events;
  bool get focusMode => _focusMode;
  DateTime? get lastSync => _lastSync;
  String get activeTab => _activeTab;
  Event? get currentCall => _currentCall;
  bool get isRepeatCall => _isRepeatCall;
  bool get isSyncing => _isSyncing;

  // Active upcoming meetings
  List<Event> get upcomingEvents {
    final now = DateTime.now();
    return _events.where((e) => e.startTime.isAfter(now.subtract(const Duration(minutes: 1)))).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // Completed history meetings sorted with newest completed event first
  List<Event> get pastEvents {
    final now = DateTime.now();
    return _events.where((e) => e.startTime.isBefore(now)).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  // Boot startup loading state
  Future<void> init() async {
    _focusMode = StorageService.loadFocusMode();
    _lastSync = StorageService.loadLastSync();
    _events = StorageService.loadEvents();
    _user = StorageService.loadUser();
    
    // Load OAuth token session
    final token = StorageService.loadAccessToken();
    final expiry = StorageService.loadTokenExpiry();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (token != null && expiry != null && nowMs < expiry) {
      _accessToken = token;
      _tokenExpiry = expiry;
    }

    // Try refreshing sign-in silently to verify credentials on app launch
    try {
      final silentResult = await AuthService.signInSilently();
      if (silentResult != null) {
        _accessToken = silentResult['accessToken'] as String;
        _tokenExpiry = DateTime.now().millisecondsSinceEpoch + 3600 * 1000;
        _user = silentResult['user'] as User;
        
        await StorageService.saveOAuthToken(_accessToken, _tokenExpiry);
        await StorageService.saveUser(_user);
      }
    } catch (e) {
      if (kDebugMode) print("Silent sign-in refresh error: $e");
    }

    // Schedule exact alarms on app boot to cover closed-state execution
    await AlarmService.scheduleReminders(_events);

    // Start precision 1-second system clock polling loop
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkReminders();
    });

    // Start auto sync background interval (30 minutes)
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      syncNow(silent: true);
    });

    notifyListeners();
  }

  // HIGH-ACCURACY SYSTEM CLOCK POLLED SCHEDULER (second-level precision, max 1s delay)
  void _checkReminders() {
    if (_focusMode || _events.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    bool hasChanges = false;
    Event? pendingCall;
    bool repeatType = false;

    // Trigger constants
    const int trigger30Ms = 30 * 60 * 1000;
    const int trigger5Ms = 5 * 60 * 1000;

    for (var ev in _events) {
      final eventMs = ev.startTime.millisecondsSinceEpoch;
      final target30Ms = eventMs - trigger30Ms;
      final target5Ms = eventMs - trigger5Ms;

      // 1. TRIGGER CONDITION 30-min call reminder
      if (!ev.reminded30 && nowMs >= target30Ms && nowMs < eventMs) {
        ev.reminded30 = true;
        hasChanges = true;
        if (pendingCall == null) {
          pendingCall = ev;
          repeatType = false;
        }
      }

      // 2. TRIGGER CONDITION 5-min repeat reminder
      if (ev.repeatScheduled && !ev.reminded5 && nowMs >= target5Ms && nowMs < eventMs) {
        ev.reminded5 = true;
        hasChanges = true;
        if (pendingCall == null) {
          pendingCall = ev;
          repeatType = true;
        }
      }
    }

    if (hasChanges) {
      StorageService.saveEvents(_events);
      notifyListeners();
    }

    if (pendingCall != null) {
      triggerCall(pendingCall, repeatType);
    }
  }

  // Trigger call screen state
  void triggerCall(Event event, bool isRepeat) {
    _currentCall = event;
    _isRepeatCall = isRepeat;
    notifyListeners();

    // Start loop voice tts
    final String timeStr = "${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')}";
    TtsService.speakMeetingAlert(event.title, timeStr);
  }

  // Accept incoming call
  void acceptCall() {
    TtsService.stopSpeech();
    // Simply announce accepted and close overlay
    _currentCall = null;
    notifyListeners();
  }

  // Decline/Dismiss incoming call
  void declineCall() {
    TtsService.stopSpeech();
    _currentCall = null;
    notifyListeners();
  }

  // Sync state or refresh silently
  Future<void> syncNow({bool silent = false}) async {
    if (_accessToken == null) return;
    
    // Check if token expired
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_tokenExpiry != null && nowMs >= _tokenExpiry!) {
      _accessToken = null;
      _tokenExpiry = null;
      StorageService.saveOAuthToken(null, null);
      notifyListeners();
      return; // UI will prompt login since token is null
    }

    if (!silent) {
      _isSyncing = true;
      notifyListeners();
    }

    try {
      final googleEvents = await ApiService.fetchEvents(_accessToken!);
      
      // Upsert into state preserving local properties
      _upsertEvents(googleEvents);
      _lastSync = DateTime.now();
      
      await StorageService.saveEvents(_events);
      await StorageService.saveLastSync(_lastSync);

      // Reschedule high-precision background alarms for closed-state triggers
      await AlarmService.scheduleReminders(_events);
    } catch (e) {
      if (kDebugMode) print("Sync error: $e");
    } finally {
      if (!silent) {
        _isSyncing = false;
        notifyListeners();
      }
    }
  }

  // Google Sign-In real production entry
  Future<String?> loginWithGoogle() async {
    final result = await AuthService.signInWithGoogle();
    if (result['success'] == true) {
      _accessToken = result['accessToken'] as String;
      _tokenExpiry = DateTime.now().millisecondsSinceEpoch + 3600 * 1000; // 1 hour session
      _user = result['user'] as User;

      await StorageService.saveOAuthToken(_accessToken, _tokenExpiry);
      await StorageService.saveUser(_user);
      
      // Attempt background calendar sync now
      await syncNow(silent: true);
      
      notifyListeners();
      return null;
    }
    return result['error'] as String? ?? 'Unknown error occurred during Google Sign-In';
  }

  // Manual event creation: timezone-compliant, behaves exactly like Google events
  Future<void> saveManualEvent({
    required String title,
    required DateTime startTime,
    String? meetingLink,
    String? agenda,
  }) async {
    final newEvent = Event(
      id: "manual_${DateTime.now().millisecondsSinceEpoch}",
      title: title,
      startTime: startTime,
      endTime: startTime.add(const Duration(minutes: 30)),
      meetingLink: meetingLink?.trim().isEmpty == true ? null : meetingLink,
      agenda: agenda?.trim().isEmpty == true ? null : agenda,
      source: "manual",
      timezone: "Asia/Kolkata",
    );

    _events.add(newEvent);
    _events.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    await StorageService.saveEvents(_events);
    // Schedule high-precision background alarms for this manual event
    await AlarmService.scheduleReminders(_events);

    switchTab('overview');
  }

  // Deletion logic (Feature 1): Bi-directional delete from calendar + local
  Future<void> deleteEvent(String evId) async {
    final eventIndex = _events.indexWhere((e) => e.id == evId);
    if (eventIndex == -1) return;

    final targetEvent = _events[eventIndex];
    
    // 1. Local delete
    _events.removeAt(eventIndex);
    await StorageService.saveEvents(_events);

    // Cancel scheduled background alarms for the deleted event
    await AlarmService.cancelReminder(evId, false);
    await AlarmService.cancelReminder(evId, true);

    // 2. Google calendar delete
    if (targetEvent.source != 'manual' && _accessToken != null) {
      try {
        await ApiService.deleteEvent(_accessToken!, evId);
      } catch (e) {
        if (kDebugMode) print("Google Calendar API delete error: $e");
      }
    }

    // Reschedule remaining active events
    await AlarmService.scheduleReminders(_events);

    notifyListeners();
  }

  // Schedule a repeating call at -5 minutes
  void scheduleRepeatCall(String evId) async {
    final idx = _events.indexWhere((e) => e.id == evId);
    if (idx != -1) {
      _events[idx].repeatScheduled = true;
      _events[idx].reminded5 = false; // Reset flags to fire on schedule
      await StorageService.saveEvents(_events);

      // Reschedule exact background alarms to pick up the new 5-minute repeating reminder
      await AlarmService.scheduleReminders(_events);
    }
    _currentCall = null;
    TtsService.stopSpeech();
    notifyListeners();
  }

  // Tab View Routing
  void switchTab(String tabName) {
    _activeTab = tabName;
    notifyListeners();
  }

  // Focus Mode Toggle
  Future<void> toggleFocusMode(bool checked) async {
    _focusMode = checked;
    await StorageService.saveFocusMode(checked);
    notifyListeners();
  }

  // Google Calendar Unsync
  Future<void> unsyncCalendar() async {
    TtsService.stopSpeech();
    _accessToken = null;
    _tokenExpiry = null;
    _user = null;
    _events = [];
    _lastSync = null;
    _focusMode = false;
    _activeTab = 'overview';
    
    await StorageService.clearAll();
    notifyListeners();
  }

  // Sign out cleanly
  Future<void> signOut() async {
    await AuthService.signOut();
    await unsyncCalendar();
  }

  // Merges fetched calendar meetings safely preserving manual lists
  void _upsertEvents(List<Event> incoming) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    
    // Keep manual events intact
    final manualEvents = _events.where((e) => e.source == 'manual').toList();

    for (var ev in incoming) {
      final existingIndex = _events.indexWhere((e) => e.id == ev.id);
      if (existingIndex >= 0) {
        final existing = _events[existingIndex];
        
        // Reset reminder status only if rescheduled far into the future
        final msUntil = ev.startTime.millisecondsSinceEpoch - nowMs;
        final shouldReset30 = msUntil > (30 * 60 * 1000 + 60000);
        final shouldReset5  = msUntil > (5 * 60 * 1000 + 60000);

        _events[existingIndex] = Event(
          id: ev.id,
          title: ev.title,
          startTime: ev.startTime,
          endTime: ev.endTime,
          meetingLink: ev.meetingLink,
          agenda: ev.agenda,
          source: ev.source,
          timezone: ev.timezone,
          rawStart: ev.rawStart,
          reminded30: shouldReset30 ? false : existing.reminded30,
          reminded5: shouldReset5 ? false : existing.reminded5,
          repeatScheduled: existing.repeatScheduled,
        );
      } else {
        _events.add(ev);
      }
    }

    // Preserve manual list
    for (var manual in manualEvents) {
      if (!_events.any((e) => e.id == manual.id)) {
        _events.add(manual);
      }
    }

    // Filter out past meetings older than 30 days
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    _events = _events.where((e) => e.startTime.isAfter(cutoff)).toList();
    _events.sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }
}
