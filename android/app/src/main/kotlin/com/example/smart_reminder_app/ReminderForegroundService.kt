package com.example.smart_reminder_app

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import androidx.core.content.getSystemService

class ReminderForegroundService : Service() {
    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val eventId = intent?.getStringExtra("eventId") ?: return START_NOT_STICKY
        val title = intent.getStringExtra("title") ?: "Meeting"
        val timeText = intent.getStringExtra("timeText") ?: "--:--"
        val isRepeat = intent.getBooleanExtra("isRepeat", false)

        val notification = buildForegroundNotification(eventId, title, timeText, isRepeat)
        startForeground(NOTIF_ID, notification)
        startRingingAndVibration()
        return START_STICKY
    }

    override fun onDestroy() {
        stopRingingAndVibration()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildForegroundNotification(
        eventId: String,
        title: String,
        timeText: String,
        isRepeat: Boolean,
    ): Notification {
        NotificationHelper.createChannel(this)

        val body = if (isRepeat) {
            "5 minutes left. $title at $timeText"
        } else {
            "30 minutes left. $title at $timeText"
        }

        val acceptIntent = NotificationHelper.acceptPendingIntent(this, eventId, title, timeText, isRepeat)
        val declineIntent = NotificationHelper.declinePendingIntent(this, eventId, isRepeat)
        val fullScreenIntent = NotificationHelper.fullScreenPendingIntent(this, eventId, title, timeText, isRepeat)

        return NotificationCompat.Builder(this, NotificationHelper.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle("Incoming Meeting Reminder")
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fullScreenIntent, true)
            .setContentIntent(fullScreenIntent)
            .addAction(android.R.drawable.ic_menu_call, "Accept", acceptIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Decline", declineIntent)
            .build()
    }

    private fun startRingingAndVibration() {
        stopRingingAndVibration()
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        ringtone = RingtoneManager.getRingtone(this, uri)
        ringtone?.play()

        vibrator = getSystemService()
        val pattern = longArrayOf(0, 1200, 700)
        vibrator?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                it.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                it.vibrate(pattern, 0)
            }
        }
    }

    private fun stopRingingAndVibration() {
        ringtone?.stop()
        ringtone = null
        vibrator?.cancel()
        vibrator = null
    }

    companion object {
        private const val NOTIF_ID = 771144
    }
}
