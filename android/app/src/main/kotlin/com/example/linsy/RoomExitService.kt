package com.example.linsy

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log

/** Tracks explicit task removal. Process death still needs server-side expiry. */
class RoomExitService : Service() {
    companion object {
        const val PREFS = "linsy_room_exit"
        const val TOKEN = "cleanup_token"

        fun register(context: Context, cleanupToken: String) {
            // Store before starting the service, in the same process as playback.
            synchronized(RoomExitService::class.java) {
                check(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit().putString(TOKEN, cleanupToken).commit())
            }
            context.startService(Intent(context, RoomExitService::class.java))
            Log.d("LinsyRoomExit", "Cleanup registered")
        }

        fun clear(context: Context) {
            synchronized(RoomExitService::class.java) {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit().remove(TOKEN).commit()
            }
            context.stopService(Intent(context, RoomExitService::class.java))
        }

        fun taskRemoved(context: Context) {
            val token = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(TOKEN, null) ?: return
            RoomExitJob.schedule(context, token)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int) = START_NOT_STICKY

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d("LinsyRoomExit", "Task removed: scheduling cleanup")
        taskRemoved(this)
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }
}
