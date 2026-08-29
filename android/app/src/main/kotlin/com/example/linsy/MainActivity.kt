package com.example.linsy

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

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