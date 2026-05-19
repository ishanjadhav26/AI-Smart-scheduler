import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final callEvent = provider.currentCall;
    
    if (callEvent == null) {
      return const SizedBox.shrink(); // safety
    }

    final String minsText = provider.isRepeatCall ? "5 minutes" : "30 minutes";
    final String timeStr = "${callEvent.startTime.hour.toString().padLeft(2, '0')}:${callEvent.startTime.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: const Color(0xFF030008), // absolute dark spaces
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Ringing Pulse Waves Background
          Positioned(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFA78BFA).withOpacity(0.04),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Top calling indicator
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.call, color: Color(0xFFEF4444), size: 14),
                          SizedBox(width: 6),
                          Text(
                            'MEETING REMINDER',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Icon(
                      Icons.keyboard_voice_rounded,
                      color: Color(0xFFA78BFA),
                      size: 64,
                    ),
                  ],
                ),

                // Meeting Information
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      Text(
                        callEvent.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Scheduled at $timeStr (IST)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Starting in $minsText',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFA78BFA),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Button Controls
                Column(
                  children: [
                    // Repeat Timer Trigger
                    if (!provider.isRepeatCall)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: OutlinedButton.icon(
                          onPressed: callEvent.repeatScheduled
                              ? null
                              : () {
                                  provider.scheduleRepeatCall(callEvent.id);
                                },
                          icon: const Icon(Icons.repeat_rounded, size: 16),
                          label: Text(
                            callEvent.repeatScheduled
                                ? 'Repeat scheduled at -5 mins'
                                : 'Repeat Call at 5 mins before',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFA78BFA),
                            side: BorderSide(
                              color: const Color(0xFFA78BFA).withOpacity(0.3),
                            ),
                            disabledForegroundColor: Colors.grey.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),

                    // Main circular Accept / Decline keys
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Decline Call
                        Column(
                          children: [
                            FloatingActionButton(
                              heroTag: 'decline_btn',
                              onPressed: () => provider.declineCall(),
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              shape: const CircleBorder(),
                              child: const Icon(Icons.call_end, size: 28),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Decline',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),

                        // Accept Call
                        Column(
                          children: [
                            FloatingActionButton(
                              heroTag: 'accept_btn',
                              onPressed: () => provider.acceptCall(),
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: const CircleBorder(),
                              child: const Icon(Icons.phone_in_talk, size: 28),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Answer',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
