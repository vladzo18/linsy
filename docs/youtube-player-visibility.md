# YouTube embed visibility

The room's remote playback state and local playback permission are separate.
`VisiblePlayerEngine` serializes synchronizer commands and blocks load/play/seek
when the surface is hidden. Hiding pauses only this device. Showing the surface
asks the synchronizer to apply the current room checkpoint, not the old position.
Native engine play commands recheck visibility after asynchronous initialization.
Both YouTube implementations cue tracks instead of starting muted autoplay.

The embed has its own region. UP NEXT is a 40px row below it. Mobile Queue/Chat
use the region beneath the player; expanding hides the participants strip, not
the video. When a keyboard or a small window leaves insufficient space, the
embed is removed and the panel explicitly indicates a local pause. Reactions
are bounded to the work panel. Routes/dialogs and app notices hide the embed
and gate playback while covering it. Minimized Windows explicitly blocks play.

The surface requires at least 200x200 logical viewport pixels and more than
half of its rectangle inside the app viewport. PiP is treated as visible only
while the activity remains resumed/inactive, never hidden/paused. PiP below the
minimum size pauses and shows a placeholder; enlarge it to resume. This is a
deliberate change from the previous compact PiP implementation.

This is not a certification of YouTube compliance or a detector of arbitrary
overlapping windows from other apps. Existing known app overlays are handled;
new overlays must also be kept outside the embed or explicitly block it.

## Physical-device acceptance still required

- Android: play, expand Queue/Chat, drag both ways, open keyboard, close keyboard.
  Video stays outside panel; hidden video pauses locally, other members continue.
- Open dialogs/settings and show a notice; no video behind the covering UI.
- Trigger UP NEXT and next/repeat transitions. Recommendations remain unobscured.
- Enter/resize PiP, close PiP, lock/unlock the screen. Check logs for absence of
  repeated PLAY attempts while hidden; next track must not start hidden.
- Windows: minimize/restore and switch focus. Confirm local pause and resync.
- Narrow viewport and large text: no overlaps or under-size playing embed.

Automated tests cover metadata/video geometry, undersized viewport, covering
routes, lifecycle, blocked sync commands and a hide-during-play race. They use
mock players and do not prove WebView/YouTube behavior on physical devices.

References:
- https://developers.google.com/youtube/terms/required-minimum-functionality
- https://developers.google.com/youtube/iframe_api_reference#cueVideoById

## Compact layout revision

Expanded Queue/Chat now use a visible compact video on the left and track/controls
on the right, including with a keyboard when space permits. The app-imposed
200-logical-pixel cutoff has been removed for embedded video and system PiP.
Hidden/off-screen video remains gated. This UX decision does not establish an
exception to YouTube's published embedded-player minimum-size requirements;
public-release compliance and the CSS/native/system-PiP sizing distinction remain
to be verified. The older minimum-size behavior described above is superseded.
