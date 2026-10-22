# NovaPresence — the iOS app (Phase 2)

Nova's body on the Emperor's iPhone: a native Swift app so she can join
calls as a present participant named **Nova** — switchable color avatar
(her face), ears that hear, a mouth that talks back, and eyes that see.

Charter: `../PROJECT.md` · Engineering: `../ARCHITECTURE.md` ·
Team: `../PARTICIPATION.md` · Why no Mac was needed: `../FREE-MACBOOK-HUNT.md`

**Phase-2 status, honestly:** the standalone call room is built — avatar,
device ears (Speech framework), device mouth (pluggable TTS), and device
eyes (camera preview) all work *without any Zoom account*. The Zoom layer
is integrated up to its boundary behind one interface: Video SDK
**sandbox** first (dev sessions only — it cannot join real Zoom
meetings), Meeting SDK (Custom UI) stubbed behind the same interface for
the real-meetings phase. The SDK binaries come from the Emperor's Zoom
accounts and are **not vendored yet**, so Zoom joins report exactly why
they can't happen yet instead of pretending. The first real compile of
this code is the first GitHub Actions run (see below) — no Mac exists
locally, and nothing here claims a build has succeeded until CI proves it.

---

## What's in the app

| Faculty | Phase-2 implementation | Production direction |
|---|---|---|
| **Face** | `Avatar/` — palette-driven 2D avatar in SwiftUI: 3 appearances (**Nova Blue / Solar Gold / Violet Dusk**, ported from the prototype), blink (2.5–5.5 s), gaze drift, breathing, listening tilt/glow, mouth driven by the speech amplitude envelope | Same avatar rendered as Nova's Zoom video track (raw video send) |
| **Ears** | `Audio/SpeechRecognitionService.swift` — microphone + Apple **Speech** framework STT, explicit permission flow, partial + final transcripts logged in-app with speaker labels | Zoom raw audio → streaming local Whisper-class STT, per-participant tags |
| **Mouth** | `Audio/TTSProvider.swift` — a **protocol**, with `DeviceSpeechTTSProvider` as the Phase-2 placeholder (device speech synthesis) and `NovaServerTTSProvider` as the production boundary | Nova's own voice **`avocado_v2:vdc_5723`** — **server-side, NOT a device voice**. The code, the UI badge, and this README all say which voice is active; nothing fakes Nova's voice |
| **Eyes** | `Vision/` — AVFoundation camera session + preview: the **room** eye (what the phone is shown) | Plus **call** eyes: Zoom raw video frames per participant, sampled 1–2 fps, downscaled, name-tagged. Room and call channels are kept separate by design |
| **Zoom** | `Zoom/` — `ZoomSessionService` protocol; `VideoSDKZoomService` (sandbox) and `MeetingSDKZoomService` (real meetings) as isolated implementations over `ZoomConfig`; default is the standalone service | Video SDK vendored first for pipeline development (10,000 free min/month, **hard-stop** at the pool — $0 law); then Meeting SDK Custom UI with host-grant privilege flow + ZAK/OBF tokens (required from 2026-03-02 for other accounts' meetings) |

Project layout:

```
app/                        ← this folder IS the git repository root
├── .github/workflows/build.yml
├── project.yml             ← XcodeGen definition (the .xcodeproj is generated)
├── Config/
│   ├── Base.xcconfig       ← optional-include of Secrets.xcconfig
│   └── Secrets.xcconfig.template   ← KEY NAMES ONLY, never filled in git
├── Sources/NovaPresence/   ← App, ContentView, Avatar/, Audio/, Vision/, Zoom/, Models/
└── Tests/NovaPresenceTests/
```

**Why XcodeGen?** With no local Mac, a hand-written `.xcodeproj` (a bundle
of plists) is unverifiable and easy to corrupt. `project.yml` is plain
text — reviewable, diffable — and CI generates the identical project from
it on every run. The generated project is git-ignored.

---

## Create the GitHub repo and push (the Emperor's browser step)

His GitHub login is saved in the Secure Vault; this step happens in his
browser, signed in as him. Nobody else can or should do it for him.

1. Go to **github.com → New repository**.
2. Name it **`nova-presence`** (or similar). Set it **Public** — public
   repos get free GitHub-hosted macOS runners; macOS minutes on a private
   repo's free plan bill at 10× and would run dry fast.
3. Do **not** add a README, .gitignore, or license (this repo brings its
   own). Create the repository.
4. Push this folder as the repo root. From any machine with this folder
   (or hand this block to whoever is at a terminal with git):

   ```bash
   cd ~/workspace/nova-presence/app
   git init
   git add .
   git commit -m "Nova Presence Phase 2: standalone call room + GitHub Actions build"
   git branch -M main
   git remote add origin https://github.com/<HIS-USERNAME>/nova-presence.git
   git push -u origin main
   ```

   Sanity-check before pushing: `git status` must **not** list
   `Config/Secrets.xcconfig` (it is git-ignored; only the `.template`
   ships) and must not list any `.xcodeproj` (generated in CI).
5. The push triggers the workflow automatically (it also runs on demand).

## Run the workflow

- **Automatic:** every push to `main` that touches Swift sources,
  `project.yml`, `Config/`, or the workflow itself.
- **Manual:** GitHub → the repo → **Actions** → *“Nova Presence — iOS
  build (unsigned)”* → **Run workflow**.
- The run takes roughly 10–25 minutes on a hosted runner (first run is
  slowest). Watch the step names — each failure says what broke:
  *Select Xcode 26* / *Verify Xcode 26* are the steps most likely to bite
  if GitHub refreshes the `macos-15` image.

### The Xcode 26 selection (critical)

The `macos-15` runner image carries Xcode 26.0.1–26.3 **but defaults to
Xcode 16.4**. The workflow therefore (a) finds the newest installed
`Xcode_26*.app`, `xcode-select`s it and pins `DEVELOPER_DIR`, then
(b) **fails the build** unless `xcodebuild -version` reports `Xcode 26.x`.
There is deliberately no fallback to an older Xcode — Xcode 26 is the
SDK line this project targets (it requires macOS Sequoia 15.6+, which is
exactly why the cloud route exists).

## Download the artifact and sideload it

1. Open the finished Actions run → **Artifacts** → download
   **`NovaPresence-unsigned`** (contains `NovaPresence-unsigned.ipa`,
   `NovaPresence-app.zip`, and `build.log`).
2. The IPA is **unsigned** by design. Sideload it with **AltStore** or
   **Sideloadly** (both run on Windows/Mac — no Mac is required):
   - Install AltStore/Sideloadly and connect the iPhone.
   - Choose `NovaPresence-unsigned.ipa`.
   - Sign in with **his free Apple ID — the Emperor enters this himself,
     on his own device. Nobody else asks for, sees, or handles it.**
   - The app installs with **7-day free provisioning**: it must be
     re-signed/refreshed weekly (AltStore can refresh over Wi-Fi), and
     free provisioning allows a small number of sideloaded apps at once.
3. First launch on the iPhone: grant **microphone, speech-recognition,
   and camera** permissions when the app asks (Settings → Nova Presence
   can change them later). Test the room: switch palettes, Start
   Listening and speak, Speak It in the Mouth panel, Open Her Eyes.

## Secrets needed later (NAMES ONLY)

No secrets are needed for the first green build. When the Emperor creates
his Zoom accounts/apps, add these as **GitHub repository secrets**
(Settings → Secrets and variables → Actions) — values never go in the
repo, the logs, or this README:

| GitHub Secret name | What it is | When |
|---|---|---|
| `ZOOM_VIDEO_SDK_KEY` | Video SDK SDK Key (sandbox account) | Phase 2, when the Video SDK account exists |
| `ZOOM_VIDEO_SDK_SECRET` | Video SDK SDK Secret — used to sign join tokens **server-side**, never embedded in the app | Same |
| `ZOOM_MEETING_SDK_KEY` | Meeting SDK Client ID / SDK Key | Later phase (real meetings) |
| `ZOOM_MEETING_SDK_SECRET` | Meeting SDK Client Secret — server-side token signing only | Same |

Today the workflow only checks whether these **exist** (true/false in the
log) to report the build mode. The SDK binaries themselves
(`ZoomVideoSDK.xcframework` / `MobileRTC`) are distributed through the
Zoom Marketplace to the account holder; vendoring them is the step that
turns the `Zoom/` stubs live, once the accounts exist.

## Honest limits

- **Unsigned = 7-day provisioning** with a free Apple ID, weekly refresh,
  small sideloaded-app limit. A paid Apple Developer account would change
  this; that is spending and therefore the Emperor's call, not assumed.
- **No Zoom keys yet** → the app runs in no-Zoom-keys standalone mode and
  says so in its Zoom panel.
- **No SDK binaries yet** → even *with* keys, Zoom joins stay at the
  boundary until the frameworks are vendored (see `Zoom/` file headers
  for the exact integration points).
- **Untested on a real device** until the Emperor's iPhone session: mic /
  camera / Speech behavior, audio routing, and battery can only be
  verified on the real body.
- **Video SDK ≠ meetings.** If anyone suggests "just use the Video SDK
  for his Zoom calls," the answer is no — Zoom's own docs say Video SDK
  sessions cannot be joined from Zoom clients or meeting links.
- **Latency:** the conversational loop budget is ~2–5 s end-to-end
  (Nova's thinking dominates) — see `../ARCHITECTURE.md`. The avatar's
  listening life-signs exist to make that read as thought, not failure.
