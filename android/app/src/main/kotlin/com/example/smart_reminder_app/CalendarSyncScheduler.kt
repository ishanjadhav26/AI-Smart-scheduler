package com.example.smart_reminder_app

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object CalendarSyncScheduler {
    fun start(context: Context) {
        val request = PeriodicWorkRequestBuilder<CalendarSyncWorker>(15, TimeUnit.MINUTES)
            .build()

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "smart_reminder_calendar_sync",
            ExistingPeriodicWorkPolicy.UPDATE,
            request,
        )
    }
}
