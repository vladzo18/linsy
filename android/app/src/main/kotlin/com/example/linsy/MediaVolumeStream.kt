package com.example.linsy

import android.content.Context
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/** Uses public audio APIs, including volume changes from headsets/system UI. */
class MediaVolumeStream(context: Context) : EventChannel.StreamHandler {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val handler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var previous: Double? = null
    private val sample = object : Runnable {
        override fun run() {
            val listener = sink ?: return
            val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
            val value = if (audio.isStreamMute(AudioManager.STREAM_MUSIC)) 0.0
                else audio.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max
            if (value != previous) {
                previous = value
                listener.success(value)
            }
            handler.postDelayed(this, 300)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        dispose()
        sink = events
        sample.run()
    }

    override fun onCancel(arguments: Any?) = dispose()

    fun dispose() {
        handler.removeCallbacks(sample)
        sink = null
        previous = null
    }
}
