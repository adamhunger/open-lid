# Open Lid

Version 0.2. A macOS menu-bar utility for using an external monitor with the MacBook lid open.

## Get the source

```sh
git clone https://github.com/adamhunger/open-lid.git
cd open-lid
```

Build from source below before installing. This repository does not include a prebuilt application.

## What it does

Keeps the MacBook lid open and keyboard/trackpad usable while disabling the
built-in display. Select your actual physical external monitor explicitly;
other displays, including virtual displays, do not satisfy that selection.
The selection is remembered by display UUID. Automatic mode starts OFF at
launch. Recovery continues after failures, with retry delays up to 30 seconds.
Polling runs during menu tracking as well as normal app operation.

## Blind restore shortcut

Hold Control + Option + Command and press R (the R key position on a US keyboard).
While Open Lid is running in your logged-in desktop session, this requests
restoration and switches automatic mode OFF. It retries if restoration fails.
It stays off until you explicitly re-enable automatic mode in the menu.

The shortcut uses Carbon RegisterEventHotKey. It registers only this combination:
no event tap, input monitoring, Accessibility permission, keylogging, or recording.
If registration fails or another application owns the shortcut, automatic mode
is disabled. The menu reports the registration error.

Limitations: wake the Mac first. Do not rely on this shortcut before login,
at the lock screen, while the app is not running, or if the app/macOS has hung.
Some secure-input situations may prevent global shortcuts. If recovery fails,
reconnect the selected monitor; restart the Mac as a last resort. This app
cannot repair failing display hardware or guarantee an image on a damaged panel.

## Install / update

1. Clone this repository and run the build commands below to create Open Lid.app.
2. Quit any older Open Lid using its Restore and quit menu item. Do not run
   multiple versions at the same time.
3. Copy Open Lid.app from the repository root to Applications
   (or your personal Applications folder). Replace an older copy if desired.
4. Open the copied app. This is locally ad-hoc signed, not Apple-notarized.
   If macOS blocks the downloaded copy, building locally is the preferred
   path; alternatively use macOS's per-app Open Anyway option only for this
   copy you trust. Do not disable Gatekeeper globally.
5. Click the ▣ menu-bar icon. Under Select your physical monitor, choose
   your real external monitor, not AirPlay, Sidecar, or a virtual display.
6. Enable External display only (automatic).
7. With the external monitor still attached, press Control–Option–Command–R
   once to test restoration. Re-enable automatic mode when ready.

No launch agent, login item, helper, or privileged service is installed.
The app must remain running. Relaunch it and enable automatic mode after login.

## Build from source

Requirements: Apple Silicon Mac; tested on M1 and macOS 26.6; Apple's Xcode
Command Line Tools with Swift. Private display APIs may differ on other releases.
No prebuilt app is included; the build uses your installed Swift toolchain.

If the command-line tools are missing, run in Terminal:

```sh
xcode-select --install
```

Then complete Apple's installation prompt.

In Terminal, change directory to the repository root (open-lid). Run:

```sh
sh Source/test.sh
sh Source/build.sh
```

The build creates Open Lid.app beside Source and signs it locally. It needs no
third-party packages, network access, paid developer account, or administrator
privileges. Install the resulting app as above. Quit the installed/running copy
before replacing it. Source/Info.plist supplies the bundle metadata.

## Source files

- Source/main.swift — display API wrapper, menu, global shortcut, application entry.
- Source/Recovery.swift — recovery and automatic-mode state machine.
- Source/RecoveryTests.swift — simulated tests; do not alter actual displays.
- Source/Info.plist — application identity and version.
- Source/build.sh — create and locally sign the application bundle.
- Source/test.sh — compile and run recovery tests in a temporary directory.

## Diagnostics (from the repository root)

```sh
'./Open Lid.app/Contents/MacOS/OpenLid' --status
```

Reports display state without changing it.

```sh
'./Open Lid.app/Contents/MacOS/OpenLid' --check-hotkey
```

Temporarily registers and releases the shortcut without changing displays.
Quit the main app before that check, since it otherwise already owns the shortcut.

## Uninstall

1. Press Control–Option–Command–R to request restoration, then choose
   Restore and quit from the menu. If restoration fails, the app keeps trying
   rather than silently exiting. Reconnect the external monitor if needed.
2. Move Open Lid.app from Applications (or its chosen location) to Trash.
3. Optionally remove its saved monitor preference after quitting:

   ```sh
   defaults delete local.openlid.app
   ```

   A missing-domain message means there are no preferences to remove.
4. Delete any other downloaded copies or source folders you no longer need.
   Nothing else is installed, and no permissions need revoking.

## Security and recovery notes

Uses Apple's private SkyLight display API, resolved from an absolute system path.
No shell commands, network access, telemetry, or global keystroke listeners run
inside the application. Display changes are process-scoped, not permanent.
Normal quitting explicitly restores the internal display; macOS is also asked
to restore the session configuration when the process ends. That private-API
crash path is not a guarantee and has not been fault-injected on this machine.
A monitor UUID is a practical selection mechanism, not proof of physical hardware
or a security boundary against other software in your own account.
After wake, the screen may briefly light before the app reapplies its setting.

## Validation

On November 18, 2026, the recovery tests passed and the app rebuilt and its local signature verified. No live display configuration was changed during these checks.

Originally compiled and signed on the development Mac (M1, macOS 26.6). Recovery tests cover monitor selection,
manual override, a remaining virtual display after physical-monitor removal,
failed restoration with repeated retries and backoff, and disable failures.
Hot-key registration checked successfully without input-monitoring permission.
The earlier version's actual disable/restore operation worked on this Mac.
The revised app still needs an interactive shortcut, unplug, and sleep/wake test.

API background consulted:
https://github.com/calvincchan/displaytoggle/blob/main/Sources/displaytoggle/DisplayManager.swift
https://developer.apple.com/documentation/foundation/timer
Implementation written independently for this local utility.
