# Session-start progress

The Qt shell presents cloud seat setup separately from local media readiness. The
Rust core already exposes the server's `seatSetupInfo.seatSetupStep` as
`activeSession.seatSetupStep`. `SessionSetupProgress.qml` translates that value
for the desktop loading screen and the console's existing `streamMessage`.

| Cloud seat step | Presentation |
| --- | --- |
| `0` | Connecting to GeForce NOW |
| `1` | Waiting for an available rig, with a queue position when supplied |
| `2`, `3`, `4` | Configuring the cloud gaming rig |
| `5` | Cleaning up the previous session |
| `6` | Waiting for cloud storage |
| Missing, invalid, or unknown | Preparing the game |

A positive queue position retains the queue presentation except when the server
explicitly reports cleanup or storage waiting. Cloud steps do not form a fixed
linear sequence and do not support a calculated percentage. Unknown values do
not imply completion or failure.

These numbers are **not** the native bridge's `NVB_SESSION_SETUP_STATE` enum.
That separate enum uses `3` for starting the streamer and `4` for seat ready.
Do not apply those meanings directly to `seatSetupStep`. The supplied SDK maps
raw steps `0`, `1`, `5`, and `6` explicitly and defaults other steps to configuring.
OpenNOW only names the bounded known range and keeps a generic future-value fallback.

## Queue polls that answer with an error status

A queued seat is polled with `GET /v2/session/{id}`. GeForce NOW answers those
polls with an error status while the queue is under pressure — the common case is
`503` with `requestStatus.statusCode: 62` and
`statusDescription: SESSION_QUEUE_LENGTH_EXCEEDED` — but the body still carries
the live `session.status` and `seatSetupInfo` for the same seat.

`get_session` in `native/opennow-core/src/cloudmatch.rs` keeps that snapshot
whenever the body describes a seat that has no rig yet (`session.status` `1` or
lower, or only a queue position, with a session ID) and the reply is either a
retryable status (`408`, `425`, `429`, `500`, `502`, `503`, `504`) or a
success status whose `requestStatus` is the queue rejection (`statusCode` `62` or
a description containing `QUEUE`). Those polls are queue progress, not failures:

- the shell receives a normal session snapshot and stays on the queue screen with
  the reported position;
- the poll does not consume `streamPollFailureAttempts`, so a long queue cannot be
  ended by the server's own queue-pressure replies;
- the snapshot is returned immediately instead of after the transient-failure
  backoff, so queue updates keep their cadence;
- the queue stall detector still counts only real movement, so a position that
  genuinely stops moving still offers "leave queue and request a fresh rig".

Authentication (`401`/`403`), missing sessions (`404`), an empty body, a body
for a seat that already has a rig, and any other rejection such as
`SESSION_EXPIRED` remain failures and keep their existing handling. Because
these polls are not failures, they also stop producing automatic bug reports
while the player is legitimately waiting in a queue.

After navigating to the stream, the existing native `starting` status displays
connection initialization. The native `streaming` status before the first-frame
handoff displays a wait for video. It does not claim that gameplay is visible.
Failure, stopping, and reconnecting retain their existing precedence. This
presentation does not change polling, cancellation, session ownership, or the
video item's lifetime.

## Evidence

The comparison used the user-supplied GeForce NOW Linux archive with SHA-256
`47ddbe0425b9ab560f64fa42a0052794c9de335ded0fd59637f082dd7a161ad4`.
Its 325 files contain 32 source maps and 2,717 recovered source entries. Reproduce
the local source index without executing the packaged client:

```sh
python3 scripts/audit-gfn-archive.py /path/to/client.zip /path/to/audit-output
```

The output includes archive file hashes and source-map provenance in
`manifest.json`. Keep the extracted proprietary files outside the repository.

The raw step mapping is in the recovered `ragnarok.js` source, at
`sources/bb8a6388e2b8b096/00004-ragnarok.js`, in the method containing
`switch(t.seatSetupInfo.seatSetupStep)`. The bridge enum is in
`sources/6231326702bae925/00854-Streaming.ts:465-480`, originally
`projects/gfn/streamer/src/app/streaming/streaming/Streaming.ts`.
The adapter's separate progress-state conversion is in
`sources/6231326702bae925/00857-session-manager-adapter.ts:514-550`.
These are bundled source definitions, not an authenticated native-Linux trace.

OpenNOW Mac's corresponding raw mapping is in
`Model/Game/OPNSessionModels.swift`, `progressState(seatSetupStep:queuePosition:)`.
The Qt core normalization is in `native/opennow-core/src/cloudmatch.rs`,
`session_info`.

## Verification

`opennow-qt/tests/theme/tst_sessionprogress.qml` covers every known raw step,
missing/invalid/future values, bounded queue positions, cleanup/storage precedence,
backward transitions, lifecycle overrides, and the native first-frame wait.

```sh
cmake --build build/opennow-qt --target opennow-theme-tests
ctest --test-dir build/opennow-qt --output-on-failure -R '^opennow-theme-tests$'
npm run locales:check
```

The existing `qml-session-launch-*` acceptance checks cover first-frame handoff,
confirmation overlays, reconnects, and the same video surface in windowed and
fullscreen modes. Run those with the complete Qt executable before shipping.
