package com.example.linsy

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.os.PersistableBundle
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

/** A network-constrained cleanup survives removal of the activity task. */
class RoomExitJob : JobService() {
    companion object {
        private const val TAG = "LinsyRoomExit"
        private const val URL_CLOSE = "https://ptgyzoaiabrmwjjwdxbu.supabase.co/functions/v1/room-exit-close"

        @Synchronized fun schedule(context: Context, token: String) {
            val scheduler = context.getSystemService(JobScheduler::class.java)
            val component = ComponentName(context, RoomExitJob::class.java)
            val pending = scheduler.allPendingJobs
            if (pending.any { it.service == component &&
                    it.extras.getString(RoomExitService.TOKEN) == token }) return
            var id = 2500
            while (pending.any { it.id == id }) id++
            val extras = PersistableBundle().apply { putString(RoomExitService.TOKEN, token) }
            val result = scheduler.schedule(JobInfo.Builder(id, component)
                .setExtras(extras)
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setBackoffCriteria(30_000, JobInfo.BACKOFF_POLICY_EXPONENTIAL)
                .build())
            Log.d(TAG, "Cleanup job scheduled: result=$result")
        }
    }

    private val running = ConcurrentHashMap<Int, JobParameters>()

    override fun onStartJob(params: JobParameters): Boolean {
        val token = params.extras.getString(RoomExitService.TOKEN) ?: return false
        // Do not retry a previous session after the user has rejoined or left.
        // The endpoint must also validate session identity for in-flight requests.
        if (getSharedPreferences(RoomExitService.PREFS, MODE_PRIVATE)
                .getString(RoomExitService.TOKEN, null) != token) return false
        running[params.jobId] = params
        thread(name = "linsy-room-exit") {
            var retry = true
            try {
                val connection = URL(URL_CLOSE).openConnection() as HttpURLConnection
                try {
                    connection.requestMethod = "POST"
                    connection.doOutput = true
                    connection.connectTimeout = 10_000
                    connection.readTimeout = 10_000
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.outputStream.use {
                        it.write(JSONObject().put("cleanupToken", token).toString().toByteArray(Charsets.UTF_8))
                    }
                    val status = connection.responseCode
                    Log.d(TAG, "Cleanup HTTP $status")
                    retry = status == 408 || status == 429 || status >= 500
                    if (status in 200..299) {
                        // An older cleanup must never erase a newly joined session.
                        val prefs = getSharedPreferences(RoomExitService.PREFS, MODE_PRIVATE)
                        synchronized(RoomExitService::class.java) {
                            if (prefs.getString(RoomExitService.TOKEN, null) == token) {
                                prefs.edit().remove(RoomExitService.TOKEN).commit()
                            }
                        }
                    } else if (!retry) {
                        Log.w(TAG, "Cleanup rejected; no automatic retry for HTTP $status")
                    }
                } finally { connection.disconnect() }
            } catch (error: Exception) {
                Log.w(TAG, "Cleanup network failure; retry scheduled", error)
            } finally {
                android.os.Handler(mainLooper).post {
                    if (running.remove(params.jobId, params)) jobFinished(params, retry)
                }
            }
        }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean {
        running.remove(params.jobId, params)
        return true
    }
}
