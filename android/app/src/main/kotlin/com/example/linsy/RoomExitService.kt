package com.example.linsy

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.Process
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

class RoomExitService : Service() {

    companion object {
        private const val TAG =
            "LinsyRoomExit"

        private const val ACTION_REGISTER =
            "com.example.linsy.room_exit.REGISTER"

        private const val ACTION_CLEAR =
            "com.example.linsy.room_exit.CLEAR"

        private const val EXTRA_CLEANUP_TOKEN =
            "cleanup_token"

        private const val PREFS =
            "linsy_room_exit"

        private const val KEY_CLEANUP_TOKEN =
            "cleanup_token"

        private const val CLOSE_URL =
            "https://ptgyzoaiabrmwjjwdxbu.supabase.co/functions/v1/room-exit-close"

        fun register(
            context: Context,
            cleanupToken: String
        ) {
            context.startService(
                Intent(
                    context,
                    RoomExitService::class.java
                )
                    .setAction(
                        ACTION_REGISTER
                    )
                    .putExtra(
                        EXTRA_CLEANUP_TOKEN,
                        cleanupToken
                    )
            )
        }

        fun clear(
            context: Context
        ) {
            context.startService(
                Intent(
                    context,
                    RoomExitService::class.java
                )
                    .setAction(
                        ACTION_CLEAR
                    )
            )
        }
    }

    private val closing =
        AtomicBoolean(false)

    override fun onCreate() {
        super.onCreate()

        Log.d(
            TAG,
            "RoomExitService created. PID=${Process.myPid()}"
        )
    }

    override fun onBind(
        intent: Intent?
    ): IBinder? {
        return null
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {

        when (intent?.action) {

            ACTION_REGISTER -> {
                registerToken(
                    intent
                )
            }

            ACTION_CLEAR -> {
                clearToken()

                stopSelf(
                    startId
                )
            }
        }

        return START_NOT_STICKY
    }

    private fun registerToken(
        intent: Intent
    ) {
        val cleanupToken =
            intent.getStringExtra(
                EXTRA_CLEANUP_TOKEN
            )

        if (
            cleanupToken.isNullOrBlank()
        ) {
            return
        }

        val saved =
            getSharedPreferences(
                PREFS,
                Context.MODE_PRIVATE
            )
                .edit()
                .putString(
                    KEY_CLEANUP_TOKEN,
                    cleanupToken
                )
                .commit()

        closing.set(
            false
        )

        Log.d(
            TAG,
            "Cleanup token registered, saved=$saved, PID=${Process.myPid()}"
        )
    }

    override fun onTaskRemoved(
        rootIntent: Intent?
    ) {
        Log.d(
            TAG,
            "Task removed from Recent Apps. PID=${Process.myPid()}"
        )

        closeMembership()

        super.onTaskRemoved(
            rootIntent
        )
    }

    private fun closeMembership() {
        if (!closing.compareAndSet(
                false,
                true
            )
        ) {
            return
        }

        val preferences =
            getSharedPreferences(
                PREFS,
                Context.MODE_PRIVATE
            )

        val cleanupToken =
            preferences.getString(
                KEY_CLEANUP_TOKEN,
                null
            )

        if (
            cleanupToken.isNullOrBlank()
        ) {
            stopSelf()

            return
        }

        Log.d(
            TAG,
            "Closing room membership... PID=${Process.myPid()}"
        )

        thread(
            name = "linsy-room-exit",
            isDaemon = false
        ) {
            try {
                val success =
                    sendCloseRequest(
                        cleanupToken
                    )

                if (success) {
                    clearToken()

                    Log.d(
                        TAG,
                        "Room membership closed."
                    )
                }
            } catch (
                error: Throwable
            ) {
                Log.e(
                    TAG,
                    "Room membership close failed.",
                    error
                )
            } finally {
                stopSelf()
            }
        }
    }

    private fun sendCloseRequest(
        cleanupToken: String
    ): Boolean {
        val connection =
            URL(
                CLOSE_URL
            ).openConnection()
                as HttpURLConnection

        try {
            connection.requestMethod =
                "POST"

            connection.doOutput =
                true

            connection.connectTimeout =
                2500

            connection.readTimeout =
                2500

            connection.setRequestProperty(
                "Content-Type",
                "application/json"
            )

            val body =
                """
                {"cleanupToken":"$cleanupToken"}
                """.trimIndent()

            connection.outputStream.use {
                output ->
                output.write(
                    body.toByteArray(
                        Charsets.UTF_8
                    )
                )
            }

            val status =
                connection.responseCode

            Log.d(
                TAG,
                "Room close returned $status, PID=${Process.myPid()}"
            )

            return status in 200..299
        } finally {
            connection.disconnect()
        }
    }

    private fun clearToken() {
        getSharedPreferences(
            PREFS,
            Context.MODE_PRIVATE
        )
            .edit()
            .clear()
            .commit()

        Log.d(
            TAG,
            "Cleanup token cleared."
        )
    }

    override fun onDestroy() {
        Log.d(
            TAG,
            "RoomExitService destroyed. PID=${Process.myPid()}"
        )

        super.onDestroy()
    }
}