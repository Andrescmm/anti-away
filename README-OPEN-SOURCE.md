# AntiAway — Open Source Reference

AntiAway is an independent, native Swift/SwiftUI macOS menu-bar application
inspired by the open-source project [`sleekhost/stay-active`](https://github.com/sleekhost/stay-active).

## Reference project

The upstream project is a small MIT-licensed Bash utility that uses Homebrew
and `cliclick` to simulate activity for Microsoft Teams and other presence-aware
apps. It periodically moves the mouse by a small random amount, sends a Shift
key event, and sometimes restores the original pointer position.

Reference repository:

<https://github.com/sleekhost/stay-active>

AntiAway is not a copy of that implementation. It keeps the high-level idea of
a periodic local activity signal, but replaces the shell daemon with a native
menu-bar application and uses Quartz directly.

## What AntiAway adds

- Native SwiftUI menu-bar interface.
- On/off status indicator.
- No pointer movement, clicks, or keyboard events.
- Configurable activity interval.
- Persisted user settings.
- Accessibility permission flow with automatic retry.
- Launch-at-login support through `SMAppService`.
- No Dock icon by default, with an explicit opt-in setting.
- Liquid Glass on supported macOS versions with a native fallback.
- Developer ID, notarized DMG distribution workflow.

## Open-source status

The project source is intentionally kept local and modular so it can continue
to evolve. Before publishing this repository publicly, choose and add a license
for the AntiAway codebase. The MIT license of `sleekhost/stay-active` applies
to that upstream project, not automatically to AntiAway.

Do not include signing certificates, notarization credentials, provisioning
profiles, or personal development data in a public repository.

## Development documentation

For the active implementation, build commands, permissions, signing, DMG
creation, App Store limitations, and testing instructions, see the main
[README.md](README.md).

## Responsible use

AntiAway posts synthetic input and requires macOS Accessibility permission. It
does not guarantee a Microsoft Teams presence state: Teams can change its idle
rules or override synthetic activity. Use it only where permitted by workplace
policy.
