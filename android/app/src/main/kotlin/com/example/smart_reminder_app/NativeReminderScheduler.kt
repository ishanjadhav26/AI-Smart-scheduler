package com.example.smart_reminder_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

object NativeReminderScheduler {
    private const val REPEAT_BIT = 0x40000000.toInt()
    private const val STAGE_SHIFT = 26
    private const val BASE_MASK = 0x03FFFFFF

    fun scheduleReminder(
        context: Context,
        eventId: String,
        title: String,
        timeText: String,
        triggerAtMs: Long,
        isRepeat: Boolean,
    ) {
        clearAcknowledged(context, eventId, isRepeat)
        cancelReminder(context, eventId, isRepeat)

        val intent = baseIntent(context, eventId, title, timeText, isRepeat, 0)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            computeRequestCode(eventId, isRepeat, 0),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMs,
            pendingIntent,
        )
    }

    fun scheduleRetry(
        context: Context,
        eventId: String,
        title: String,
        timeText: String,
        isRepeat: Boolean,
        stage: Int,
        delayMs: Long,
    ) {
        val intent = baseIntent(context, eventId, title, timeText, isRepeat, stage)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            computeRequestCode(eventId, isRepeat, stage),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis() + delayMs,
            pendingIntent,
        )
    }

    fun cancelReminder(context: Context, eventId: String, isRepeat: Boolean) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (stage in 0..2) {
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                computeRequestCode(eventId, isRepeat, stage),
                baseIntent(context, eventId, "", "", isRepeat, stage),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
        NotificationHelper.cancelNotification(context, eventId, isRepeat)
        clearAcknowledged(context, eventId, isRepeat)
    }

    fun computeRequestCode(eventId: String, isRepeat: Boolean, stage: Int): Int {
        val base = baseHash(eventId)
        val stageBits = (stage.coerceIn(0, 2) shl STAGE_SHIFT)
        return base or stageBits or if (isRepeat) REPEAT_BIT else 0
    }

    fun computeAuxRequestCode(eventId: String, isRepeat: Boolean, offset: Int): Int {
        val repeatBits = if (isRepeat) REPEAT_BIT else 0
        return (baseHash(eventId) xor (offset shl 20) xor repeatBits) and 0x7FFFFFFF
    }

    private fun baseHash(eventId: String): Int {
        var hash = 0x811C9DC5.toInt()
        eventId.forEach { ch ->
            hash = hash xor ch.code
            hash = (hash * 0x01000193) and 0x7FFFFFFF
        }
        return hash and BASE_MASK
    }

    fun isAcknowledged(context: Context, eventId: String, isRepeat: Boolean): Boolean {
        val prefs = context.getSharedPreferences("smart_reminder_native", Context.MODE_PRIVATE)
        return prefs.getBoolean(ackKey(eventId, isRepeat), false)
    }

    fun markAcknowledged(context: Context, eventId: String, isRepeat: Boolean) {
        val prefs = context.getSharedPreferences("smart_reminder_native", Context.MODE_PRIVATE)
        prefs.edit().putBoolean(ackKey(eventId, isRepeat), true).apply()

        // Also write to FlutterSharedPreferences so the active Flutter UI can sync state
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val flutterKey = "flutter.sra_call_ack_${if (isRepeat) "r" else "n"}_$eventId"
        flutterPrefs.edit().putBoolean(flutterKey, true).apply()
    }

    fun markDeclined(context: Context, eventId: String, isRepeat: Boolean) {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val flutterKey = "flutter.sra_call_declined_${if (isRepeat) "r" else "n"}_$eventId"
        flutterPrefs.edit().putBoolean(flutterKey, true).apply()
    }

    fun clearAcknowledged(context: Context, eventId: String, isRepeat: Boolean) {
        val prefs = context.getSharedPreferences("smart_reminder_native", Context.MODE_PRIVATE)
        prefs.edit().remove(ackKey(eventId, isRepeat)).apply()

        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val flutterKey = "flutter.sra_call_ack_${if (isRepeat) "r" else "n"}_$eventId"
        flutterPrefs.edit().remove(flutterKey).apply()
    }

    private fun ackKey(eventId: String, isRepeat: Boolean): String {
        return "ack_${if (isRepeat) "r" else "n"}_$eventId"
    }

    private fun baseIntent(
        context: Context,
        eventId: String,
        title: String,
        timeText: String,
        isRepeat: Boolean,
        stage: Int,
    ): Intent {
        return Intent(context, ReminderAlarmReceiver::class.java).apply {
            putExtra("eventId", eventId)
            putExtra("title", title)
            putExtra("timeText", timeText)
            putExtra("isRepeat", isRepeat)
            putExtra("stage", stage)
        }
    }
}
