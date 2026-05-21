package com.example.smart_reminder_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters

class CalendarSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {

    override fun doWork(): Result {
        if (ContextCompat.checkSelfPermission(
                applicationContext,
                Manifest.permission.READ_CALENDAR,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return Result.success()
        }

        val now = System.currentTimeMillis()
        val until = now + 7L * 24 * 60 * 60 * 1000
        val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
        android.content.ContentUris.appendId(builder, now)
        android.content.ContentUris.appendId(builder, until)

        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
        )

        val cursor = applicationContext.contentResolver.query(
            builder.build(),
            projection,
            null,
            null,
            "${CalendarContract.Instances.BEGIN} ASC",
        ) ?: return Result.success()

        val seenIds = mutableSetOf<String>()
        cursor.use {
            while (it.moveToNext()) {
                val eventId = it.getLong(0).toString()
                val title = it.getString(1) ?: "Meeting"
                val beginMs = it.getLong(2)
                if (beginMs <= now) continue

                seenIds.add(eventId)
                val triggerAt = beginMs - 30L * 60 * 1000
                val effectiveTriggerAt = if (triggerAt > now) triggerAt else now + 5_000L
                val timeText = java.text.SimpleDateFormat(
                    "HH:mm",
                    java.util.Locale.getDefault(),
                ).format(java.util.Date(beginMs))
                NativeReminderScheduler.scheduleReminder(
                    applicationContext,
                    eventId,
                    title,
                    timeText,
                    effectiveTriggerAt,
                    false,
                )
            }
        }

        cancelRemovedEvents(seenIds)
        saveSeenIds(seenIds)
        return Result.success()
    }

    private fun cancelRemovedEvents(currentIds: Set<String>) {
        val prefs = applicationContext.getSharedPreferences("smart_reminder_native", Context.MODE_PRIVATE)
        val previousIds = prefs.getStringSet("calendar_watcher_ids", emptySet()) ?: emptySet()
        for (eventId in previousIds) {
            if (!currentIds.contains(eventId)) {
                NativeReminderScheduler.cancelReminder(applicationContext, eventId, false)
            }
        }
    }

    private fun saveSeenIds(ids: Set<String>) {
        val prefs = applicationContext.getSharedPreferences("smart_reminder_native", Context.MODE_PRIVATE)
        prefs.edit().putStringSet("calendar_watcher_ids", ids).apply()
    }
}
