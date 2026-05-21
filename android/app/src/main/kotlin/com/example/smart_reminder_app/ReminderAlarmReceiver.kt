package com.example.smart_reminder_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val eventId = intent.getStringExtra("eventId") ?: return
        val title = intent.getStringExtra("title") ?: "Meeting"
        val timeText = intent.getStringExtra("timeText") ?: "--:--"
        val isRepeat = intent.getBooleanExtra("isRepeat", false)
        val stage = intent.getIntExtra("stage", 0)

        if (NativeReminderScheduler.isAcknowledged(context, eventId, isRepeat)) {
            NotificationHelper.cancelNotification(context, eventId, isRepeat)
            return
        }

        NotificationHelper.showReminderNotification(context, eventId, title, timeText, isRepeat)
        val serviceIntent = Intent(context, ReminderForegroundService::class.java).apply {
            putExtra("eventId", eventId)
            putExtra("title", title)
            putExtra("timeText", timeText)
            putExtra("isRepeat", isRepeat)
        }
        ContextCompat.startForegroundService(context, serviceIntent)

        val activityIntent = Intent(context, ReminderActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("eventId", eventId)
            putExtra("title", title)
            putExtra("timeText", timeText)
            putExtra("isRepeat", isRepeat)
        }
        try {
            context.startActivity(activityIntent)
        } catch (_: Exception) {
        }

        if (stage < 2) {
            NativeReminderScheduler.scheduleRetry(
                context,
                eventId,
                title,
                timeText,
                isRepeat,
                stage + 1,
                20_000L,
            )
        }
    }
}
