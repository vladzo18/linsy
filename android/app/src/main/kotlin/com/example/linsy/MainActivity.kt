package com.example.linsy

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import android.util.Log
import android.media.AudioManager

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var mediaVolumeStream: MediaVolumeStream? = null

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        mediaVolumeStream?.dispose()
        mediaVolumeStream = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
    override fun onResume() {
        super.onResume()
        volumeControlStream = AudioManager.STREAM_MUSIC
    }
    private var pipChannel: MethodChannel? = null
    private var pipEligible = false

    private fun supportsPip() = Build.VERSION.SDK_INT >= 26 &&
        packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun pipParams(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9))
        if (Build.VERSION.SDK_INT >= 31) {
            builder.setAutoEnterEnabled(pipEligible).setSeamlessResizeEnabled(false)
        }
        return builder.build()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (supportsPip() && pipEligible && Build.VERSION.SDK_INT < 31) {
            try { enterPictureInPictureMode(pipParams()) }
            catch (error: Exception) { Log.w("LinsyPiP", "Cannot enter PiP", error) }
        }
    }

    override fun onPictureInPictureModeChanged(active: Boolean, config: Configuration) {
        super.onPictureInPictureModeChanged(active, config)
        pipChannel?.invokeMethod("changed", active)
    }

    companion object {
        private const val CHANNEL =
            "linsy/room_exit"
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(
            flutterEngine
        )
        mediaVolumeStream = MediaVolumeStream(applicationContext)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "linsy/media_volume")
            .setStreamHandler(mediaVolumeStream)

        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "linsy/pip")
        pipChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    pipEligible = call.argument<Boolean>("enabled") == true
                    try {
                        if (supportsPip()) setPictureInPictureParams(pipParams())
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("PIP", error.message, null)
                    }
                }
                "isActive" -> result.success(supportsPip() && isInPictureInPictureMode)
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "linsy/room_playback")
            .setMethodCallHandler { call, result ->
                val roomId = call.argument<String>("roomId")
                if (roomId.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENTS", "Missing room id.", null)
                    return@setMethodCallHandler
                }
                try {
                    when (call.method) {
                        "update" -> {
                            RoomPlaybackService.update(applicationContext, roomId,
                                call.argument<String>("title") ?: "Linsy",
                                call.argument<Boolean>("playing") ?: false,
                                call.argument<Number>("positionMs")?.toLong() ?: 0L)
                            result.success(null)
                        }
                        "stop" -> {
                            RoomPlaybackService.stop(applicationContext, roomId)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("PLAYBACK_SERVICE", error.message, null)
                }
            }

        MethodChannel(
            flutterEngine
                .dartExecutor
                .binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "register" -> {
                    val cleanupToken =
                        call.argument<String>(
                            "cleanupToken"
                        )

                    if (
                        cleanupToken.isNullOrBlank()
                    ) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Missing cleanup token.",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    RoomExitService.register(
                        context =
                            applicationContext,
                        cleanupToken =
                            cleanupToken
                    )

                    result.success(null)
                }

                "clear" -> {
                    RoomExitService.clear(
                        applicationContext
                    )

                    result.success(null)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
