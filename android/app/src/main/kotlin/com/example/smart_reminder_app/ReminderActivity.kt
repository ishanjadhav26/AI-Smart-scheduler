package com.example.smart_reminder_app

import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class ReminderActivity : AppCompatActivity() {
    private lateinit var eventId: String
    private var isRepeat: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            )
        }

        eventId = intent.getStringExtra("eventId") ?: ""
        isRepeat = intent.getBooleanExtra("isRepeat", false)
        val title = intent.getStringExtra("title") ?: "Meeting"
        val timeText = intent.getStringExtra("timeText") ?: "--:--"

        NotificationHelper.cancelNotification(this, eventId, isRepeat)
        playRingtone(this)
        setContentView(buildLayout(title, timeText))
    }

    private fun buildLayout(title: String, timeText: String): LinearLayout {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xFF05010A.toInt())
            gravity = Gravity.CENTER
            setPadding(48, 96, 48, 96)
        }

        val label = TextView(this).apply {
            text = "Meeting Reminder"
            textSize = 18f
            setTextColor(0xFFE5D9FF.toInt())
            gravity = Gravity.CENTER
        }
        val titleView = TextView(this).apply {
            text = title
            textSize = 28f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
        }
        val timeView = TextView(this).apply {
            text = if (isRepeat) "Starts in 5 minutes at $timeText" else "Starts in 30 minutes at $timeText"
            textSize = 16f
            setTextColor(0xFFB8B0C7.toInt())
            gravity = Gravity.CENTER
        }
        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        val decline = Button(this).apply {
            text = "Decline"
            setOnClickListener { handleAction(false) }
        }
        val accept = Button(this).apply {
            text = "Accept"
            setOnClickListener { handleAction(true) }
        }

        buttonRow.addView(decline)
        buttonRow.addView(accept)

        root.addView(label)
        root.addView(titleView)
        root.addView(timeView)
        root.addView(buttonRow)
        return root
    }

    private fun handleAction(accepted: Boolean) {
        NativeReminderScheduler.markAcknowledged(this, eventId, isRepeat)
        NotificationHelper.cancelNotification(this, eventId, isRepeat)
        stopRingtone()
        if (accepted) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            prefs.edit()
                .putString("flutter.sra_pending_call_event_id", eventId)
                .putBoolean("flutter.sra_pending_call_is_repeat", isRepeat)
                .apply()
            startActivity(intentForMain())
        } else {
            NativeReminderScheduler.markDeclined(this, eventId, isRepeat)
        }
        finish()
    }

    private fun intentForMain() = android.content.Intent(this, MainActivity::class.java).apply {
        flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
            android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP
    }

    override fun onDestroy() {
        stopRingtone()
        super.onDestroy()
    }

    companion object {
        private var ringtone: Ringtone? = null

        fun playRingtone(activity: AppCompatActivity) {
            stopRingtone()
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(activity, uri)
            ringtone?.play()
        }

        fun stopRingtone() {
            ringtone?.stop()
            ringtone = null
        }
    }
}
