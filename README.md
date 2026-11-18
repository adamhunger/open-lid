# Open Lid

Version 0.2. A macOS menu-bar utility for using an external monitor with the MacBook lid open.

## What it does

Keeps the MacBook lid open and keyboard/trackpad usable while disabling the
built-in display. Select your actual physical external monitor explicitly;
other displays, including virtual displays, do not satisfy that selection.
The selection is remembered by display UUID. Automatic mode starts OFF at
launch. Recovery continues after failures, with retry delays up to 30 seconds.
Polling runs during menu tracking as well as normal app operation.

## Installation

This repository contains source code only. There is no prebuilt download; you
build the app on your own Mac in about a minute, then copy it to your
Applications folder.

### 1. Requirements

- Apple Silicon Mac (tested on M1, macOS 26.6). Private display APIs may differ
  on other releases.
- Apple's Xcode Command Line Tools, which include the Swift compiler. If you are
  not sure they are installed, run this in Terminal and follow the prompt:

  ```sh
  xcode-select --install
  ```

  If it reports the tools are already installed, you are ready.

No third-party packages, network access during the build, paid developer
account, or administrator privileges are needed.

### 2. Get the source

```sh
git clone https://github.com/adamhunger/open-lid.git
cd open-lid
```

### 3. Build the app

From the repository root (the `open-lid` folder):

```sh
sh Source/test.sh
sh Source/build.sh
```

`test.sh` runs the recovery tests in a temporary directory; they do not touch
your real displays. `build.sh` compiles the app, signs it locally, and creates
`Open Lid.app` in the repository root.

### 4. Install the app

Copy the whole `Open Lid.app` bundle to your Applications folder. Either drag it
there in Finder, or run one of these:

```sh
# System-wide Applications folder
cp -R "Open Lid.app" /Applications/

# Or your personal Applications folder (no admin password needed)
mkdir -p ~/Applications
cp -R "Open Lid.app" ~/Applications/
```

Copy the entire `Open Lid.app` folder, not the `OpenLid` file inside
`Open Lid.app/Contents/MacOS`. On macOS the `.app` folder is the application.
The bare executable will not behave as an app: it has no icon, is not
recognized by Finder or Login Items, and loses its menu-bar-only setting.

If you are replacing an older copy, quit it first with its Restore and quit
menu item. Do not run two versions at the same time.

### 5. First launch

Open the copied app from Finder, or:

```sh
open ~/Applications/"Open Lid.app"
```

The app is signed with a local ad-hoc signature, not Apple-notarized. Because
you built it on this Mac, Gatekeeper normally lets it open without complaint.
If macOS does block it, go to System Settings > Privacy & Security and use
Open Anyway for this one app. Do not disable Gatekeeper globally.

Open Lid is a menu-bar app. It has no Dock icon and no window. Look for the
▣ icon in the menu bar at the top-right of the screen.

### 6. Configure

1. Click the ▣ menu-bar icon.
2. Under Select your physical monitor, choose your real external monitor. Do
   not choose AirPlay, Sidecar, or a virtual display.
3. Enable External display only (automatic). The built-in display turns off
   while the external monitor is connected.
4. With the external monitor still attached, press Control–Option–Command–R
   once to test restoration. The built-in display should come back and
   automatic mode switches off.
5. Re-enable External display only (automatic) when ready.

### 7. Launch at login (optional)

The app installs no login item, launch agent, or helper by itself. If you want
it to start automatically when you log in, add it as a macOS Login Item.

Using System Settings:

1. Open System Settings > General > Login Items & Extensions.
2. Under Open at Login, click the + button.
3. Select Open Lid.app from your Applications folder and click Open.

Or from Terminal (adjust the path if you installed to /Applications):

```sh
osascript -e 'tell application "System Events" to make login item at end with properties {path:"'"$HOME"'/Applications/Open Lid.app", hidden:false}'
```

Automatic mode always starts OFF when the app launches, by design. After each
login you still need to click the ▣ icon and enable External display only
(automatic). The monitor selection is remembered.

To stop launching at login, remove Open Lid from the Open at Login list in
System Settings, or run:

```sh
osascript -e 'tell application "System Events" to delete login item "Open Lid"'
```

### 8. Updating

1. In the repository folder, run `git pull`.
2. Rebuild with `sh Source/test.sh` and `sh Source/build.sh`.
3. Quit the running Open Lid using its Restore and quit menu item.
4. Copy the new `Open Lid.app` over the old one as in step 4.
5. Open the app again. Your login item and monitor selection are kept.

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

## Build notes

The build uses your installed Swift toolchain and needs no third-party
packages, network access, paid developer account, or administrator privileges.
`Source/build.sh` creates `Open Lid.app` beside `Source` and signs it locally.
`Source/Info.plist` supplies the bundle metadata. The built app is ignored by
git, so each clone must be built before it can be installed.

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
2. If you added a login item, remove Open Lid from System Settings > General >
   Login Items & Extensions, or run:

   ```sh
   osascript -e 'tell application "System Events" to delete login item "Open Lid"'
   ```

3. Move Open Lid.app from Applications (or its chosen location) to Trash.
4. Optionally remove its saved monitor preference after quitting:

   ```sh
   defaults delete local.openlid.app
   ```

   A missing-domain message means there are no preferences to remove.
5. Delete any other downloaded copies or source folders you no longer need.
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

## Disclaimer

Open Lid relies on private Apple frameworks (SkyLight) that are undocumented
and unsupported. Any macOS update may change or remove them, which could make
the app stop working or behave unexpectedly. When automatic mode is on, the
built-in display is disabled until the app restores it, you press
Control–Option–Command–R, or the app quits. If the app and macOS both fail,
you may need to reconnect the external monitor or restart the Mac to get the
built-in display back.

This software is provided as is, without warranty of any kind, as stated in
the MIT License. Use it at your own risk. Open Lid is an independent project
and is not affiliated with, endorsed by, or supported by Apple Inc. macOS,
MacBook, Xcode, and Swift are trademarks of Apple Inc.

## Acknowledgments

The SkyLight approach used here, calling `SLSGetDisplayList` to find the
built-in display while it is disabled and `SLSConfigureDisplayEnabled` to turn
it on or off, was learned by reading Calvin C. Chan's
[displaytoggle](https://github.com/calvincchan/displaytoggle) command-line
tool. Open Lid's implementation was written independently; no code was copied
from that project.

Apple's [Timer documentation](https://developer.apple.com/documentation/foundation/timer)
informed the polling design.

## Author and maintainer

Adam Hunger ([@adamhunger](https://github.com/adamhunger) on GitHub).
Issues and pull requests are welcome at
https://github.com/adamhunger/open-lid.

## License

Open Lid is released under the [MIT License](LICENSE).
Copyright (c) 2026 Adam Hunger.
