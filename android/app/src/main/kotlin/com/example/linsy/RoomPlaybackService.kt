package com.example.linsy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaMetadata
import android.media.AudioAttributes
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/** Keeps the existing room/player process alive while the activity is backgrounded.
 * Not sticky: the WebView player cannot be resurrected independently after process death.
 */
class RoomPlaybackService : Service() {
    companion object {
        private const val CHANNEL = "room_playback"
        private const val ID = 2401
        private var current: RoomPlaybackService? = null
        private var latestRoomId: String? = null

        fun update(context: Context, roomId: String, title: String, playing: Boolean, position: Long) {
            latestRoomId = roomId
            val intent = Intent(context, RoomPlaybackService::class.java)
                .putExtra("roomId", roomId).putExtra("title", title)
                .putExtra("playing", playing).putExtra("position", position)
            val service = current
            if (service != null) {
                service.publish(intent)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context, roomId: String) {
            // Ignore delayed cleanup from a room that has already been replaced.
            if (latestRoomId == roomId) {
                latestRoomId = null
                context.stopService(Intent(context, RoomPlaybackService::class.java))
            }
        }
    }

    private lateinit var session: MediaSession
    private lateinit var wakeLock: PowerManager.WakeLock
    private var roomId: String? = null

    override fun onCreate() {
        super.onCreate()
        current = this
        session = MediaSession(this, "Linsy room playback")
        session.setPlaybackToLocal(AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
        session.isActive = true
        wakeLock = (getSystemService(POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "linsy:room-playback")
        wakeLock.setReferenceCounted(false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL, "Room playback", NotificationManager.IMPORTANCE_LOW)
            channel.description = "Current room track and return to Linsy"
            channel.setSound(null, null)
            channel.enableVibration(false)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent.getStringExtra("roomId") == latestRoomId) {
            publish(intent)
        } else if (latestRoomId == null) {
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun publish(intent: Intent) {
        roomId = intent.getStringExtra("roomId")
        val title = intent.getStringExtra("title") ?: "Linsy"
        val playing = intent.getBooleanExtra("playing", false)
        val open = Intent(this, MainActivity::class.java)
            .setAction(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pending = PendingIntent.getActivity(this, ID, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        session.setSessionActivity(pending)
        session.setMetadata(MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, "Linsy • Room playback")
            .build())
        session.setPlaybackState(PlaybackState.Builder()
            .setActions(0)
            .setState(if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                intent.getLongExtra("position", 0), if (playing) 1f else 0f)
            .build())
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder.setSmallIcon(R.drawable.ic_music_notification)
            .setContentTitle(title)
            .setContentText(if (playing) "Playing in your room" else "Paused • Tap to return")
            .setContentIntent(pending)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setStyle(Notification.MediaStyle().setMediaSession(session.sessionToken))
            .setOnlyAlertOnce(true).setShowWhen(false).setOngoing(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(ID, notification)
        }
        if (playing && !wakeLock.isHeld) wakeLock.acquire()
        if (!playing && wakeLock.isHeld) wakeLock.release()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        RoomExitService.taskRemoved(this)
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        if (current === this) current = null
        if (wakeLock.isHeld) wakeLock.release()
        session.isActive = false
        session.release()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
