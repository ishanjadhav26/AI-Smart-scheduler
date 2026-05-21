package com.example.smart_reminder_app

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channelName = "smart_reminder/native_alarm"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Ensure the activity can show over the lock screen and turn the screen on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                android.view.WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleReminder" -> {
                    val eventId = call.argument<String>("eventId")
                    val title = call.argument<String>("title")
                    val timeText = call.argument<String>("timeText")
                    val triggerAtMs = call.argument<Number>("triggerAtMs")
                    val isRepeat = call.argument<Boolean>("isRepeat") ?: false

                    if (eventId == null || title == null || timeText == null || triggerAtMs == null) {
                        result.error("bad_args", "Missing reminder data", null)
                        return@setMethodCallHandler
                    }

                    NativeReminderScheduler.scheduleReminder(
                        this,
                        eventId,
                        title,
                        timeText,
                        triggerAtMs.toLong(),
                        isRepeat,
                    )
                    result.success(null)
                }
                "cancelReminder" -> {
                    val eventId = call.argument<String>("eventId")
                    val isRepeat = call.argument<Boolean>("isRepeat") ?: false
                    if (eventId == null) {
                        result.error("bad_args", "Missing eventId", null)
                        return@setMethodCallHandler
                    }
                    NativeReminderScheduler.cancelReminder(this, eventId, isRepeat)
                    result.success(null)
                }
                "startCalendarWatcher" -> {
                    CalendarSyncScheduler.start(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
