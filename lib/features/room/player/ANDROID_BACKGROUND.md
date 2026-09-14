# Android background playback

`RoomPlaybackService` holds a foreground media session and a partial wake lock while playback is active. Flutter publishes the current track through `RoomPlaybackNotification`; tapping the notification returns to the existing app activity. Leaving the room stops the service. Removing the task also stops it, consistently with room-exit cleanup.

This keeps the existing WebView-based player process running; it does not replace YouTube with a native audio source, restart playback after process death, or implement iOS background audio. YouTube/WebView background behavior still requires device verification. No visibility spoofing or audio extraction is implemented.

Validation: Kotlin compilation, Dart analysis and bridge tests (track changes, pause, empty playback, exit racing with queued updates).

Device acceptance, after a full Android rebuild (not hot reload):
1. Join a room and play a track. Verify title in the system media notification.
2. Press Home while playing: verify a visible 16:9 PiP window containing only the video and continuing audio. Android controls its size. Lock-screen playback is not supported by this implementation.
3. Change the room track from another device; verify notification and sound both update.
4. Tap the notification and verify the existing room opens without reconnecting.
5. Leave the room or remove the task; verify notification disappears and audio stops.
6. Use device media-volume buttons, including volume 0, and pause/resume; verify system volume is preserved. Native Android/iOS player gain is 1.0; desktop retains its independent slider and saved default.

Device logs on 2026-09-14 confirmed that hiding the activity stops the WebView audio even while the foreground service and Dart synchronization remain alive. PiP is the next device experiment, not a verified lock-screen playback solution. Android 12+ uses automatic entry; Android 8–11 uses `onUserLeaveHint`. Paused playback and routes covering the room disable entry. The same keyed WebView is moved into the PiP layout without creating a second player. Verify returning, closing PiP, changing tracks, and disabling the system PiP permission on a physical device.

The user confirmed PiP playback on their device. Invite eligibility and dismissal now belong to the RoomPage session, surviving destruction of the normal layout during PiP.

Task removal cleanup: both RoomExitService and the foreground RoomPlaybackService enqueue a deduplicated JobScheduler request using the registered cleanup token. They share the app process/preferences. Network failures, HTTP 408/429 and 5xx retry with backoff; other non-success codes are logged. Jobs from superseded local tokens are skipped. The server must validate session identity for requests already in flight. Force-stop, OEM process killing before callbacks, and reboot require server-side membership expiry; client callbacks cannot guarantee cleanup. Backend code/schema are not present in this workspace.

On device, swipe the task out of Recents and inspect `LinsyRoomExit`: expect `Cleanup job scheduled` followed by `Cleanup HTTP 2xx`, then verify membership disappears on another device. Repeat offline and reconnect before rejoining. Scheduling may be delayed by Android. Separately verify Home/PiP never triggers cleanup.
