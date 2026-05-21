package com.example.smart_reminder_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ReminderActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val eventId = intent.getStringExtra("eventId") ?: return
        val isRepeat = intent.getBooleanExtra("isRepeat", false)

        NativeReminderScheduler.markAcknowledged(context, eventId, isRepeat)
        NotificationHelper.cancelNotification(context, eventId, isRepeat)
        ReminderActivity.stopRingtone()

        if (intent.action == "com.example.smart_reminder_app.ACCEPT") {
            writeFlutterPendingCall(context, intent)
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            context.startActivity(launchIntent)
        }
    }

    private fun writeFlutterPendingCall(context: Context, intent: Intent) {
        val eventId = intent.getStringExtra("eventId") ?: return
        val isRepeat = intent.getBooleanExtra("isRepeat", false)
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("flutter.sra_pending_call_event_id", eventId)
            .putBoolean("flutter.sra_pending_call_is_repeat", isRepeat)
            .apply()
    }
}
