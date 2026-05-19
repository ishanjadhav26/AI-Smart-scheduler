import 'dart:convert';

class Event {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? meetingLink;
  final String? agenda;
  final String source; // 'google' | 'manual'
  final String timezone;
  final String? rawStart; // For timezone debug logs

  bool reminded30;
  bool reminded5;
  bool repeatScheduled;

  Event({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.meetingLink,
    this.agenda,
    required this.source,
    required this.timezone,
    this.rawStart,
    this.reminded30 = false,
    this.reminded5 = false,
    this.repeatScheduled = false,
  });

  // Convert to JSON for localStorage caching (shared_preferences)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'meetingLink': meetingLink,
      'agenda': agenda,
      'source': source,
      'timezone': timezone,
      'rawStart': rawStart,
      'reminded30': reminded30,
      'reminded5': reminded5,
      'repeatScheduled': repeatScheduled,
    };
  }

  // Parse from local JSON cache
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      meetingLink: json['meetingLink'] as String?,
      agenda: json['agenda'] as String?,
      source: json['source'] as String,
      timezone: json['timezone'] as String,
      rawStart: json['rawStart'] as String?,
      reminded30: json['reminded30'] as bool? ?? false,
      reminded5: json['reminded5'] as bool? ?? false,
      repeatScheduled: json['repeatScheduled'] as bool? ?? false,
    );
  }

  // Parse from Google Calendar API v3 Event JSON
  factory Event.fromGoogleJson(Map<String, dynamic> json) {
    final start = json['start'] as Map<String, dynamic>?;
    final end = json['end'] as Map<String, dynamic>?;

    // Google Calendar API returns start.dateTime (or start.date for all-day events)
    final rawStartStr = (start?['dateTime'] ?? start?['date'] ?? '') as String;
    final rawEndStr = (end?['dateTime'] ?? end?['date'] ?? '') as String;

    // Parse the start/end as DateTime. Since Google returns UTC (Z) or specific offsets,
    // DateTime.parse() automatically parses it correctly.
    // We then convert it to local timezone time (.toLocal()) to ensure it displays in IST.
    final parsedStart = DateTime.parse(rawStartStr).toLocal();
    final parsedEnd = rawEndStr.isNotEmpty 
        ? DateTime.parse(rawEndStr).toLocal()
        : parsedStart.add(const Duration(minutes: 30));

    // Resolve meeting link (hangoutLink or location if it contains http)
    String? resolvedLink = json['hangoutLink'] as String?;
    final location = json['location'] as String?;
    if (resolvedLink == null && location != null && location.startsWith('http')) {
      resolvedLink = location;
    }

    return Event(
      id: json['id'] as String,
      title: (json['summary'] ?? '(No Title)') as String,
      startTime: parsedStart,
      endTime: parsedEnd,
      meetingLink: resolvedLink,
      agenda: json['description'] as String?,
      source: 'google',
      timezone: (start?['timeZone'] ?? 'Asia/Kolkata') as String,
      rawStart: rawStartStr,
      reminded30: false,
      reminded5: false,
      repeatScheduled: false,
    );
  }
}
