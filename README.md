# Whisper

A personal, fully on-device dictation app for Apple Silicon Macs — hold a hotkey, speak, and
get a cleaned-up transcript pasted wherever your cursor is. Inspired by [Wispr Flow](https://wisprflow.ai),
built from scratch to run entirely locally with no cloud calls.

## Features

- **Push-to-talk hotkey** — hold **Cmd+Ctrl**, speak, release. No letter key involved.
- **On-device transcription** — uses Apple's `SFSpeechRecognizer` with `requiresOnDeviceRecognition`,
  so audio never leaves your Mac.
- **On-device polish pass** — raw transcript is cleaned up (punctuation, capitalization, filler
  words, false starts) by Apple's on-device LLM (`FoundationModels` / Apple Intelligence). No API
  keys, no network calls.
- **Auto-paste** — the polished text is pasted into whatever app is focused, and your previous
  clipboard contents are restored afterward.
- **Menu bar app** — no Dock icon, lives entirely in the menu bar.
- **Custom vocabulary** — add names, jargon, or product terms via "Edit Custom Words…" in the
  menu to improve recognition accuracy.
- **Launch at Login** — optional, toggle from the menu.

## Requirements

- Apple Silicon Mac
- macOS 26 (Tahoe) or later
- [Apple Intelligence](https://support.apple.com/en-us/121115) enabled in System Settings (used
  for the on-device polish pass)
- Xcode (for building from source — Swift 6.2+ toolchain)

## Getting started

### Option A: Download a prebuilt build

Grab the latest `Whisper.app.zip` from the [Releases](../../releases) page, unzip it, and move
`Whisper.app` wherever you like (e.g. `/Applications`).

Since this isn't signed with a paid Apple Developer ID, the first time you open it macOS will
show a warning that it "could not verify Whisper is free of malware," with only **Move to
Trash** / **Done** as options — this is expected for an indie app distributed outside the App
Store, not a sign anything is wrong. To open it anyway:

1. Click **Done** (not "Move to Trash").
2. Open **System Settings → Privacy & Security**, then scroll down near the bottom.
3. You'll see a line like *"'Whisper' was blocked from use because it is not from an identified
   developer,"* with an **Open Anyway** button next to it — click it, and confirm with your
   password or Touch ID if asked.
4. Open `Whisper.app` again — it'll show one more confirmation dialog, this time with a real
   **Open** button.

Once it launches, you'll be prompted for Microphone, Speech Recognition, and Accessibility
permissions — grant all three (see [Permissions](#permissions) below for why).

### Option B: Build from source

```bash
git clone https://github.com/julianmackrel/whisper.git
cd whisper
./Scripts/make-dev-cert.sh   # one-time: creates a local code-signing identity
./Scripts/bundle-app.sh      # builds Whisper.app
open Whisper.app
```

`make-dev-cert.sh` creates a self-signed local codesigning certificate so that permission grants
(Microphone/Speech/Accessibility) survive rebuilds — without it, every rebuild gets a new identity
and macOS will re-prompt for all three permissions each time.

To rebuild after making changes, just re-run `./Scripts/bundle-app.sh`.

## Usage

1. Click into any text field.
2. Hold **Cmd+Ctrl** and speak.
3. Release — after a brief "Transcribing… / Polishing…" moment, the cleaned-up text is pasted in.

Click the menu bar mic icon for status, and to toggle **Enabled**, **Launch at Login**, or edit
your **Custom Words** list.

## Permissions

| Permission | Why |
|---|---|
| Microphone | Captures audio while you hold the hotkey. |
| Speech Recognition | Powers on-device transcription via `SFSpeechRecognizer`. |
| Accessibility | Needed to detect the global Cmd+Ctrl hotkey and to simulate the paste keystroke. |

All processing happens on-device — no audio or text is sent anywhere.

## Project layout

```
Sources/Whisper/
  main.swift                      # NSApplication bootstrap, menu-bar-only (.accessory)
  App/                            # AppDelegate, status bar menu, login item toggle
  Hotkey/ChordMonitor.swift       # Cmd+Ctrl chord detection
  Speech/DictationSession.swift   # AVAudioEngine + SFSpeechRecognizer capture
  Speech/VocabularyStore.swift    # Custom vocabulary file (contextualStrings biasing)
  Polish/                         # PolishEngine protocol + FoundationModels implementation
  Paste/ClipboardPaster.swift     # Clipboard write + synthetic Cmd+V + restore
  Permissions/                    # Mic/Speech/Accessibility permission bootstrap
Scripts/
  make-dev-cert.sh                # One-time local codesigning identity
  bundle-app.sh                   # swift build -c release -> Whisper.app
```

## Known limitations

- Recognition accuracy on uncommon names/jargon depends on Apple's on-device speech model — use
  the custom vocabulary list to help, but it won't be perfect.
- Requires Apple Intelligence to be available and enabled on the machine; there's no cloud
  fallback by design.
- Unsigned-by-Apple builds aren't notarized, so a plain double-click hits a Gatekeeper warning —
  see [Option A](#option-a-download-a-prebuilt-build) above for the one-time System Settings
  approval step.

## License

MIT — see [LICENSE](LICENSE).
