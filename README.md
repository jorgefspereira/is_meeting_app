# IsMeeting

A lightweight macOS menu bar app that detects when you're in a meeting and notifies third-party services via webhook.

## What it does

IsMeeting sits quietly in your menu bar and watches for camera or microphone activity. When it detects a meeting starting or ending, it fires a POST request to a webhook URL of your choice — useful for automating smart home devices, updating a Slack status, triggering Home Assistant automations, or anything else that can receive an HTTP request.

- `video.fill` icon → currently in a meeting
- `video` icon → not in a meeting

## Detection

IsMeeting uses low-level system APIs rather than AVFoundation to ensure broad compatibility:

- **Camera** — CoreMediaIO `kCMIODevicePropertyDeviceIsRunningSomewhere` detects any camera active in any process, including iPhone Continuity Camera
- **Microphone** — CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` detects any audio input device active in any process, including Bluetooth HFP headphones

No camera or microphone permission is required for detection to work.

## Webhook payload

A POST request is sent to your configured URL whenever the meeting status **changes** (not on every poll tick).

**Meeting started:**
```json
{ "state": "on" }
```

**Meeting ended:**
```json
{ "state": "off" }
```

The `Content-Type` header is set to `application/json`. The configured URL is prefixed with `https://` automatically, so enter only the domain and path in Settings.

## Requirements

- macOS 14 or later
- Xcode 16 or later (to build from source)

## Build & Run

Open `IsMeeting/IsMeeting.xcodeproj` in Xcode and press **Cmd+R**, or build from the command line:

```bash
xcodebuild build \
  -project IsMeeting/IsMeeting.xcodeproj \
  -scheme IsMeeting
```

No external dependencies or package manager required.

## Install as a local app

1. **Product → Archive** in Xcode
2. In the Organizer: **Distribute App → Custom → Copy App**
3. Drag `IsMeeting.app` to `/Applications`
4. Right-click → **Open** the first time to bypass Gatekeeper (app is not notarized)
5. Enable **Launch at Login** in Settings → General

## Settings

| Setting | Description |
|---|---|
| Launch at Login | Registers/unregisters the app with `SMAppService` |
| Webhook URL | Domain and path to POST status changes to (without `https://`) |
| Report Feedback | Placeholder for future feedback flow |

## Project structure

```
IsMeeting/IsMeeting/
├── IsMeetingApp.swift     # App entry point, MenuBarExtra scene
├── ContentView.swift      # Menu popover UI + MeetingStatusMonitor
├── SettingsView.swift     # Settings window (General + About tabs)
└── IsMeeting.entitlements # Sandbox entitlements
```

## License

MIT © 2026 Jorge Pereira
