package com.example.smart_reminder_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object NotificationHelper {
    const val CHANNEL_ID = "smart_reminder_native_calls"
    private const val CHANNEL_NAME = "Native Meeting Calls"
    private const val CHANNEL_DESC = "Full-screen meeting reminder alerts"

    fun showReminderNotification(
        context: Context,
        eventId: String,
        title: String,
        timeText: String,
        isRepeat: Boolean,
    ) {
        createChannel(context)

        val bodyText = if (isRepeat) {
            "5 minutes left. $title starts at $timeText."
        } else {
            "30 minutes left. $title starts at $timeText."
        }

        val fullScreenPendingIntent = fullScreenPendingIntent(context, eventId, title, timeText, isRepeat)
        val acceptPendingIntent = acceptPendingIntent(context, eventId, title, timeText, isRepeat)
        val declinePendingIntent = declinePendingIntent(context, eventId, isRepeat)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle("Incoming Meeting Reminder")
            .setContentText(bodyText)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .addAction(android.R.drawable.ic_menu_call, "Accept", acceptPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Decline", declinePendingIntent)
            .build()

        NotificationManagerCompat.from(context).notify(
            notificationId(eventId, isRepeat),
            notification,
        )
    }

    fun cancelNotification(context: Context, eventId: String, isRepeat: Boolean) {
        NotificationManagerCompat.from(context).cancel(notificationId(eventId, isRepeat))
    }

    private fun notificationId(eventId: String, isRepeat: Boolean): Int {
        return NativeReminderScheduler.computeAuxRequestCode(eventId, isRepeat, 33)
    }

    fun fullScreenPendingIntent(
        context: Context,
        eventId: String,
        title: String,
        timeText: String,
        isRepeat: Boolean,
    ): PendingIntent {
        val fullScreenIntent = Intent(context, ReminderActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("eventId", eventId)
            putExtra("title", title)
            putExtra("timeText", timeText)
            putExtra("isRepeat", isRepeat)
        }
        return PendingIntent.getActivity(
            context,
            NativeReminderScheduler.computeAuxRequestCode(eventId, isRepeat, 30),
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun acceptPendingIntent(
        context: Context,
        eventId: String,
        title: String,
        timeText: String,
        isRepeat: Boolean,
    ): PendingIntent {
        val acceptIntent = Intent(context, ReminderActionReceiver::class.java).apply {
            action = "com.example.smart_reminder_app.ACCEPT"
            putExtra("eventId", eventId)
            putExtra("title", title)
            putExtra("timeText", timeText)
            putExtra("isRepeat", isRepeat)
        }
        return PendingIntent.getBroadcast(
            context,
            NativeReminderScheduler.computeAuxRequestCode(eventId, isRepeat, 31),
            acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun declinePendingIntent(
        context: Context,
        eventId: String,
        isRepeat: Boolean,
    ): PendingIntent {
        val declineIntent = Intent(context, ReminderActionReceiver::class.java).apply {
            action = "com.example.smart_reminder_app.DECLINE"
            putExtra("eventId", eventId)
            putExtra("isRepeat", isRepeat)
        }
        return PendingIntent.getBroadcast(
            context,
            NativeReminderScheduler.computeAuxRequestCode(eventId, isRepeat, 32),
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = CHANNEL_DESC
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }
}
