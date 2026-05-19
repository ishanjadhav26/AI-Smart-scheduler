import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/event.dart';
import '../providers/app_provider.dart';

class MeetingCard extends StatelessWidget {
  final Event event;

  const MeetingCard({super.key, required this.event});

  // Launch external URL securely
  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    // Compute Date Format strings
    final monthStr = DateFormat.MMM().format(event.startTime).toUpperCase();
    final dayStr = DateFormat.d().format(event.startTime);

    // Compute range string
    final startTimeStr = DateFormat.jm().format(event.startTime).toLowerCase();
    final endTimeStr = DateFormat.jm().format(event.endTime).toLowerCase();
    final dateRangeText = "$startTimeStr – $endTimeStr";

    // Compute minutes until event
    final now = DateTime.now();
    final difference = event.startTime.difference(now);
    final mins = difference.inMinutes;

    // Resolve badges matching style.css rules
    String statusLabel = 'Upcoming';
    Color badgeColor = const Color(0xFF64748B); // later

    if (mins <= 5) {
      statusLabel = 'NOW';
      badgeColor = const Color(0xFFEF4444); // imminent (red)
    } else if (mins <= 30) {
      statusLabel = '${mins}m away';
      badgeColor = const Color(0xFFEF4444); // imminent (red)
    } else if (mins <= 1440) {
      statusLabel = 'Today';
      badgeColor = const Color(0xFF38BDF8); // today (blue)
    }

    // Determine custom reminder debug text logs
    String reminderLog = '';
    if (event.source == 'manual' || event.startTime.isAfter(now)) {
      if (event.reminded30) {
        if (event.repeatScheduled) {
          reminderLog = event.reminded5 ? '🔔 Both sent' : '🔁 Repeat pending';
        } else {
          reminderLog = '✅ Reminded';
        }
      } else {
        reminderLog = mins <= 30 ? '⏳ Call imminent' : '📞 Call in ${mins - 30}m';
      }
    } else {
      reminderLog = 'Completed';
    }

    // Conditional Join Meeting button: ONLY exists if meetingLink is not null or empty
    final bool hasJoinLink = event.meetingLink != null && event.meetingLink!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F091A), // deep card back matching css
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mins <= 30 
              ? const Color(0xFFEF4444).withOpacity(0.2) // imminent glow
              : const Color(0xFFA78BFA).withOpacity(0.08), // standard purple border
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA78BFA).withOpacity(0.02),
            blurRadius: 10,
          )
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 450;

          if (isMobile) {
            // Adaptive Mobile Layout
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Box
                    Container(
                      width: 50,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        border: Border.all(color: const Color(0xFFA78BFA).withOpacity(0.12)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            monthStr,
                            style: const TextStyle(
                              color: Color(0xFFA78BFA),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            dayStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_filled_rounded,
                                size: 12,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  dateRangeText,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reminderLog,
                            style: TextStyle(
                              color: const Color(0xFFA78BFA).withOpacity(0.7),
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if (event.agenda != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              "📝 ${event.agenda}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF1F1235), height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Badge Countdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.12),
                        border: Border.all(color: badgeColor.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Action Buttons Row
                    Row(
                      children: [
                        if (hasJoinLink) ...[
                          IconButton(
                            icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                            tooltip: 'Join Meeting',
                            color: const Color(0xFF10B981),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981).withOpacity(0.08),
                              padding: const EdgeInsets.all(8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _launchUrl(event.meetingLink!),
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          tooltip: 'Delete Meeting',
                          color: const Color(0xFFEF4444),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444).withOpacity(0.08),
                            padding: const EdgeInsets.all(8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF0F091A),
                                title: const Text('Delete Meeting', style: TextStyle(color: Colors.white)),
                                content: const Text(
                                  'Are you sure you want to delete this meeting?',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      provider.deleteEvent(event.id);
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          }

          // Desktop/Tablet Horizontal Row Layout
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Date Box
              Container(
                width: 52,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(color: const Color(0xFFA78BFA).withOpacity(0.12)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      monthStr,
                      style: const TextStyle(
                        color: Color(0xFFA78BFA),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      dayStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Title Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_filled_rounded,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateRangeText,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reminderLog,
                      style: TextStyle(
                        color: const Color(0xFFA78BFA).withOpacity(0.7),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (event.agenda != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "📝 ${event.agenda}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Status Countdown & Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          border: Border.all(color: badgeColor.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mins > 0 ? "in ${mins}m" : "started",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasJoinLink) ...[
                        IconButton(
                          icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                          tooltip: 'Join Meeting',
                          color: const Color(0xFF10B981),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981).withOpacity(0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _launchUrl(event.meetingLink!),
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        tooltip: 'Delete Meeting',
                        color: const Color(0xFFEF4444),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444).withOpacity(0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF0F091A),
                              title: const Text('Delete Meeting', style: TextStyle(color: Colors.white)),
                              content: const Text(
                                'Are you sure you want to delete this meeting?',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    provider.deleteEvent(event.id);
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class HistoryCard extends StatelessWidget {
  final Event event;

  const HistoryCard({super.key, required this.event});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthStr = DateFormat.MMM().format(event.startTime).toUpperCase();
    final dayStr = DateFormat.d().format(event.startTime);
    final startTimeStr = DateFormat.jm().format(event.startTime).toLowerCase();
    final endTimeStr = DateFormat.jm().format(event.endTime).toLowerCase();
    final dateRangeText = "$startTimeStr – $endTimeStr";

    final bool hasJoinLink = event.meetingLink != null && event.meetingLink!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0714).withOpacity(0.6), // dimmer history
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFA78BFA).withOpacity(0.04),
        ),
      ),
      child: Opacity(
        opacity: 0.7, // completed dim
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 450;

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Box
                      Container(
                        width: 50,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          border: Border.all(color: const Color(0xFFA78BFA).withOpacity(0.06)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              monthStr,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              dayStr,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateRangeText,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF1F1235), height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          'Completed',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (hasJoinLink)
                        IconButton(
                          icon: const Icon(Icons.link, size: 16, color: Colors.grey),
                          tooltip: 'Launch Link',
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _launchUrl(event.meetingLink!),
                        ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Date Box
                Container(
                  width: 52,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    border: Border.all(color: const Color(0xFFA78BFA).withOpacity(0.06)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        monthStr,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        dayStr,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Middle Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateRangeText,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Status & link
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (hasJoinLink) ...[
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.link, size: 16, color: Colors.grey),
                        tooltip: 'Launch Link',
                        onPressed: () => _launchUrl(event.meetingLink!),
                      )
                    ]
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
