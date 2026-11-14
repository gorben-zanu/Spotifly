# Spotify refuses this account's audio keys, and a play goes to another device

Status: **Open** 2026-11-14. Written, not yet built or run: the machine this came up on has
Command Line Tools only, and SwiftUI's macro plugin (`libSwiftUIMacros.dylib`) ships inside
Xcode. Unconfirmed on a device: the handover itself, which only needs Soloist (or a phone)
active.
Components: `Spotifly/SwiftLibrespot/Core/Errors.swift` (`isPermanentAudioKeyRefusal`),
`Spotifly/SwiftLibrespot/Public/LibrespotClient.swift` (`playbackFailed`, `autoAdvance`),
`Spotifly/ViewModels/PlaybackViewModel.swift` (`audioKeysRefused`, `resolvedPlaybackTarget`,
`startLocally`, `startLocallyOrElsewhere`), the `error.audio_key_refused` string in
`en/de/fr.lproj/Localizable.strings`
Found: 2026-11-14, a play in a signed-in Premium account failing with `Audio key error: 1` and
nothing else.

## Summary

Signing in, the library, search and another device's playback all work; every local start
fails with `Audio key error: 1`. That code is a **permanent refusal of the account**, not a
bad request: the same answer for every track, on all six accesspoints (gew1/gue1/gew4/gae2,
ports 4070/443/80) and with three device ids, measured with a probe compiled from this
repository's own `Accesspoint`/`APResolver`/proto/crypto files against the app's stored
credentials. It is librespot#1649, which the maintainers pinned on 2026-11-07: accounts created
after a cutoff in 2024/2025 are refused, code 1 means permanent (code 2 is a burst that clears
up), and the official clients play those accounts through a decryption scheme that is not
available to librespot.

So this Mac cannot stream for such an account, and no change here makes it. What changes is
where the app sends a play, and what it says when it cannot: a refused start marks the session
and the play is handed to the device that is playing, which for a headless official client
(Spotify Soloist, `brew install --cask spotify-soloist`) is real audio again.

## Problem

1. `playbackTarget(local:activeDeviceId:)` returns `.local` whenever this Mac can stream, which
   it can — the session is up and `streams` is true, because the account *is* Premium. Every
   play from a list therefore goes to the local player, which refuses it.
2. The refusal reaches the user as `Audio key error: 1`, which reads as a bug in the request
   rather than as an account-level fact, and offers nothing to do next.
3. The client publishes the failure as a `PlaybackInterruption` unconditionally, so a message
   about a refusal that a remote device could have absorbed lands in the bar regardless.
4. Nothing remembers the answer, so every start pays for a metadata request, an audio-key
   request and a CDN resolve before failing.

## Solution

The refusal is named once, in `LibrespotError.isPermanentAudioKeyRefusal` (`audioKeyError(1)`),
and its `errorDescription` becomes a sentence that says what happened and what to do, in all
three languages.

`LibrespotClient.playbackFailed` stays the one place a failure ends playback, but no longer
interrupts for this error: the app has a caller to explain it to, and a device to hand it to.
Auto-advance, which has no caller, says it there (`autoAdvance(to:)`).

`PlaybackViewModel` keeps the answer for the session (`audioKeysRefused`, cleared by
`performInitialization`, so the next launch tries locally again):

- `resolvedPlaybackTarget` sends a play to `player.activeRemoteDeviceId` once the refusal is
  known, rather than to the local player that will refuse it;
- `startLocallyOrElsewhere` handles the start that *learns* the refusal: it runs the local
  start, and on `isPermanentAudioKeyRefusal` hands the same `ConnectCommand` to the device that
  was active when the row was clicked. `play` and `playTracks` both go through it, so a list's
  Play button behaves like a row's double-click.

With nothing else active there is nowhere better to send the play: it is attempted locally, and
the bar carries the sentence. That is the honest degradation, and it is what an account that
can stream nowhere should hear.

**What is deliberately not done:** no retry and no pacing of the key request (the answer cannot
change), no persisted refusal across launches (an account that starts being granted keys
recovers by itself), and no change to `localPlayback` or `LocalPlayback` — a case for this would
have to be answered by every switch that already asks whether this Mac can play, and the answer
is still yes, only not for this account.

## Verification

Not yet run. To check, with a device active (Soloist paired, or a phone playing):

1. Click a row in a playlist. Expected: it plays on the other device, this Mac stays quiet, and
   the bar names nothing. With `-D DEBUG` the log says
   `PlaybackViewModel: Spotify refused the keys; playing on <device id> instead`.
2. Click a row again. Expected: no local attempt at all — no metadata or key request in the
   `AudioKey`/`AudioPipeline` log lines before the remote command.
3. Untick the other device, so nothing is active, and click a row. Expected: the bar says
   "Spotify refuses playback keys for this account, so this Mac cannot play it. Start playback
   on another device."
4. Let a track end on this Mac after a refused start. Expected: one message, not one per track,
   and the queue keeps its place (`AutoAdvance` already stops on anything but
   `trackUnavailable`).
5. Reconnect (Playing On ▸ Reconnect) and click a row. Expected: one local attempt, then the
   handover — the session that knew is gone.
