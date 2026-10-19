# AntiAway

AntiAway is a native SwiftUI menu-bar utility for macOS that sends a narrow,
non-clicking Quartz mouse-moved event at the pointer's current position. It is
designed for users who want Teams (or another presence-aware app) to observe
activity while they are reading, thinking, or away from the keyboard.

## Reference analysis: `sleekhost/stay-active`

The reference project is a small Bash daemon. Its installer adds Homebrew and
the `cliclick` command-line tool, then places a script in `~/.local/bin`.
Starting the daemon creates a control file and a background process. Every
30–60 seconds (with occasional shorter bursts) it:

1. Reads the current pointer position with `cliclick`.
2. Moves the pointer by a random 1–5 pixel offset.
3. Presses and releases Shift.
4. Restores the pointer position in most cycles.
5. Sleeps again and appends to a local log.

That approach is simple and transparent, but it has several drawbacks for a
modern macOS app: it requires Homebrew, grants Accessibility access to a shell
and helper binary, visibly moves the pointer, generates keyboard events, has no
native settings UI, and has limited lifecycle/error handling. AntiAway keeps
the useful idea (a periodic local activity signal) while using one signed app,
Quartz directly, a menu-bar UI, persisted settings, and the system login-item
API.

## Architecture

- **SwiftUI + `MenuBarExtra`**: native menu-bar UI with a compact window-style
  popover and a Settings scene.
- **`AppState`**: the main-actor view model. It persists the enabled state and
  interval in `UserDefaults`, owns the timer, exposes the permission/status
  indicator, and converts service failures into user-facing errors.
- **`DailySchedule`**: evaluates persisted daily start/end times, including
  overnight windows, and schedules a single low-power timer for the next
  boundary. Equal start and end times represent an all-day schedule.
- **`ActivityPosting` / `ActivitySimulator`**: a small protocol and Quartz
  implementation. The concrete implementation checks Accessibility access,
  reads Quartz's global pointer location, and posts only `.mouseMoved` at that
  same location. No clicks, key presses, pointer movement, screenshots, or
  input recording are performed.
- **`LoginItemService`**: wraps `SMAppService.mainApp` for launch-at-login.
- **`UpdateService` + Sparkle 2**: checks a signed HTTPS appcast, verifies
  update archives with AntiAway's EdDSA public key, and presents Sparkle's
  native update installation UI.
- **`LiquidGlassSurface`**: uses macOS 26 Liquid Glass when available and a
  native material fallback on macOS 14–25.
- **`LSUIElement`**: the app has no Dock icon; it is intentionally menu-bar
  only by default. The Appearance setting can switch the activation policy to
  a regular app and show a Dock icon when explicitly enabled.

The Xcode project lives in `AntiAway.xcodeproj` and source is grouped by
responsibility under `AntiAway/`.

## Daily schedule

The optional daily schedule automatically starts and stops activity at the
selected local times. It supports daytime windows such as 09:00–17:00 and
overnight windows such as 22:00–06:00. While scheduling is enabled, the manual
activity switch is locked to avoid conflicting state. Disabling the schedule
returns control to the user's previously saved manual preference.

## Requirements

- macOS 14 Sonoma or later
- Xcode 26 or later (the project references the macOS 26 Liquid Glass API and
  falls back at runtime on macOS 14–25)
- An Apple Development identity for local signing, or Developer ID Application
  for distribution

## Permissions

AntiAway needs one permission: **System Settings → Privacy & Security →
Accessibility**. The permission is requested only when the user turns the
feature on. It is required because macOS protects posting synthetic HID
events. AntiAway does not request Input Monitoring, Screen Recording, camera,
microphone, or location access. When update checks are enabled, Sparkle makes
an HTTPS request to AntiAway's public update feed on GitHub. Anonymous system
profiling is explicitly disabled.

Grant access to **AntiAway.app itself**, not only Xcode or Terminal. macOS
stores this permission for the executable identity/path that posts the event;
when testing a newly built copy, remove stale AntiAway entries and add the
current app from its build folder.

On some macOS releases, TCC caches the old trust result for a running debug
process. If the entry is enabled but AntiAway still reports that permission is
required, quit and relaunch the exact same app bundle that was added to the
Accessibility list. Use a stable derived-data path while testing so the app
path and identity do not change between launches.

If permission is denied, the toggle stays off and the menu shows an actionable
error with a button to open the Accessibility pane. The app also re-checks the
permission before every activity post. If the user had requested AntiAway to
be enabled, returning to the app after granting permission automatically starts
the activity timer; no process restart or second toggle is required.

## Run in Xcode

1. Open `AntiAway.xcodeproj`.
2. Select the **AntiAway** target and set a unique bundle identifier and your
   Development Team under Signing & Capabilities.
3. Build and run with **⌘R**.
4. Open the menu-bar item, enable AntiAway, and approve Accessibility access.
5. Enable **Launch at login** if desired.

## Build from Terminal

```sh
xcodebuild -project AntiAway.xcodeproj -scheme AntiAway \
  -configuration Release -sdk macosx \
  -derivedDataPath build/DerivedData build
```

The resulting app is at
`build/DerivedData/Build/Products/Release/AntiAway.app`.

## Automatic updates

AntiAway 1.1.0 and later use Sparkle 2.9.6. Users can enable automatic update
checks or run **Check for Updates…** from Settings. Checks are disabled by
default until the user opts in; no system profile is sent. Downloads are
validated with Sparkle's EdDSA signature in addition to Developer ID signing
and Apple notarization.

The update feed is:

```text
https://raw.githubusercontent.com/Andrescmm/anti-away/main/appcast.xml
```

Users on a version older than 1.1.0 must install 1.1.0 manually once. Later
versions can update in place as long as the bundle identifier and signing
identity remain stable.

The private EdDSA key was created by Sparkle and is stored in the developer's
login Keychain under the `ed25519` account. It must never be committed. Back it
up securely outside this repository using Sparkle's `generate_keys -x` option;
losing it complicates signing future updates.

### Publish an update

1. Increment `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the target.
2. Archive, export with Developer ID, notarize, and create the stapled DMG as
   described below.
3. Write optional Markdown release notes, for example
   `build/AntiAway-1.2.0.md`.
4. Generate the signed appcast entry:

```sh
./scripts/generate_appcast.sh 1.2.0 \
  build/AntiAway.dmg build/AntiAway-1.2.0.md
```

5. Create GitHub release `v1.2.0` and upload the generated
   `build/sparkle-updates/AntiAway-1.2.0.dmg`.
6. Commit and push the updated `appcast.xml` only after the release asset is
   available. Existing installations will then discover the release.

Always keep old appcast entries and release assets available so older clients
retain a valid upgrade path. Test from an older notarized build before making
the feed public.

## Create a signed `.app`

For local testing, use an Apple Development identity. For distribution
outside the Mac App Store, use a **Developer ID Application** certificate and
an appropriate Team ID:

```sh
xcodebuild -project AntiAway.xcodeproj -scheme AntiAway \
  -configuration Release -archivePath build/AntiAway.xcarchive \
  archive DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
```

Create an `ExportOptions.plist` containing at least:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>YOUR_TEAM_ID</string>
</dict></plist>
```

Then export, notarize, and staple:

```sh
xcodebuild -exportArchive -archivePath build/AntiAway.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist
ditto -c -k --keepParent build/export/AntiAway.app build/AntiAway.zip
xcrun notarytool submit build/AntiAway.zip \
  --keychain-profile YOUR_NOTARY_PROFILE --wait
xcrun stapler staple build/export/AntiAway.app
codesign --verify --deep --strict --verbose=2 build/export/AntiAway.app
```

## Create a shareable `.dmg`

Create the disk image only after exporting the signed app:

```sh
rm -rf build/dmg-root
mkdir -p build/dmg-root
cp -R build/export/AntiAway.app build/dmg-root/
ln -s /Applications build/dmg-root/Applications

hdiutil create -volname AntiAway \
  -srcfolder build/dmg-root \
  -ov -format UDZO build/AntiAway.dmg

# Recommended: notarize the exact artifact you will share.
xcrun notarytool submit build/AntiAway.dmg \
  --keychain-profile YOUR_NOTARY_PROFILE --wait
xcrun stapler staple build/AntiAway.dmg
xcrun stapler validate build/AntiAway.dmg
```

You can share the resulting `build/AntiAway.dmg` from a website, GitHub
release, or private company portal. Users open the image, drag AntiAway into
Applications, launch it, and grant Accessibility access. A DMG is a delivery
container; it is not a substitute for Developer ID signing and notarization.

## Mac App Store status

The current target is **not ready for the Mac App Store**. Apple requires Mac
App Store apps to use App Sandbox, while this target intentionally remains
unsandboxed so it can post Quartz synthetic input events. Apple’s review rules
also impose additional restrictions on auto-launch/background behavior and
apps that control other applications. See Apple’s [App Sandbox requirement](https://developer.apple.com/documentation/security/app-sandbox)
and [Mac App Store review rules](https://developer.apple.com/app-store/review/guidelines/).

The practical distribution path for this implementation is Developer ID +
notarized DMG. A separate App Store edition would require a sandboxed target,
an App Store-compatible activity mechanism, revised login/background behavior,
and an explicit review with Apple; it cannot be assumed that the current
synthetic-event implementation will be accepted.

The target deliberately does not enable App Sandbox: posting Quartz HID
events requires the unsandboxed distribution model. Review this decision with
your organization's security and signing requirements before shipping.

## Limitations and responsible use

- Teams owns its presence rules. It can change idle detection, ignore
  synthetic events, or override the result with manual status, calls, screen
  sharing, lock state, organization policy, or a future client release.
- macOS may coalesce or defer timers while the system sleeps or is under power
  pressure. AntiAway does not prevent sleep and does not claim to keep a
  locked/sleeping Mac active.
- Posting a mouse-moved event is intentionally minimal, but it is still
  synthetic input and requires trust from the user. Use it only where it is
  permitted by workplace policy.
- The interval is a coarse user preference (30 seconds to 4 minutes). A longer
  interval lowers wakeups and battery use but may not beat a service with a
  shorter idle threshold.

## Implementation checklist

The project is functional now: menu-bar toggle, status indicator, persisted
interval, enabled state, and Dock visibility, login-item registration,
permission flow, error handling, Liquid Glass/fallback styling, and a no-Dock
default are all implemented in the source tree. The first production steps are
to set your
bundle identifier/team, test Accessibility behavior on each supported macOS
release, and sign/notarize the resulting app.
