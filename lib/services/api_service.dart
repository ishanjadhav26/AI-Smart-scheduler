import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/event.dart';
import '../models/user.dart';

class ApiService {
  static const String _baseUrl = 'https://www.googleapis.com/calendar/v3';

  // Fetches upcoming Google Calendar events from primary calendar
  static Future<List<Event>> fetchEvents(String accessToken) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    
    // Request upcoming meetings sorted by startTime (ascending)
    final url = Uri.parse(
      '$_baseUrl/calendars/primary/events'
      '?timeMin=$nowUtc'
      '&orderBy=startTime'
      '&singleEvents=true'
      '&maxResults=50',
    );

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      
      // Parse items through fromGoogleJson which handles automatic conversion to local IST
      return items.map((item) => Event.fromGoogleJson(item as Map<String, dynamic>)).toList();
    } else if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception('UNAUTHORIZED_OAUTH_TOKEN');
    } else {
      throw Exception('Failed to fetch events from Google Calendar: ${res.statusCode} ${res.body}');
    }
  }

  // Deletes an event from Google Calendar using the primary events API
  static Future<void> deleteEvent(String accessToken, String eventId) async {
    final url = Uri.parse('$_baseUrl/calendars/primary/events/$eventId');
    
    final res = await http.delete(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Failed to delete event from Google Calendar: ${res.statusCode} ${res.body}');
    }
  }

  // Fetches authenticated profile userinfo
  static Future<User> fetchUserProfile(String accessToken) async {
    final url = Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo');
    
    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (res.statusCode == 200) {
      final info = jsonDecode(res.body) as Map<String, dynamic>;
      return User(
        email: (info['email'] ?? '') as String,
        name: (info['name'] ?? info['email'] ?? 'User') as String,
      );
    } else {
      throw Exception('Failed to fetch Google profile info: ${res.statusCode}');
    }
  }
}
