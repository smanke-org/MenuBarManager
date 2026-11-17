# Menu Bar Manager

Menu Bar Manager tidies your Mac's menu bar. A chevron sits in the menu bar: the items of the apps you don't need all the time stay out of sight until you click it, and the ones you use every day stay right where they are. It's built for macOS 27, where older menu bar organizers no longer hide items reliably and some apps keep drifting into the hidden area. Here each app keeps the section you gave it, however macOS places its items.

## Download

### [⬇ Download Menu Bar Manager for Mac](https://github.com/smanke-org/MenuBarManager/releases/latest/download/MenuBarManager.dmg)

1. Open `MenuBarManager.dmg`.
2. Drag Menu Bar Manager to Applications. It must run from the Applications folder: only from there does macOS keep its chevron visible while other items are hidden.
3. Open Menu Bar Manager, then turn it on under System Settings › Privacy & Security › Device Control and Data Access, so it can list and move menu bar items.

Requires macOS 27 or later. Free.

## Features

- **Three sections per app.** Shown items are always visible, Hidden items appear when you click the chevron, and Always Hidden items appear only when you ⌥-click it. Pick each app's section in Settings › Items.
- **⌘-drag to arrange.** ⌘-drag an item to the left of the chevron to hide its app, or to the right to show it. Settings and the menu bar always agree.
- **Instant, no blinking.** Items hide and show at once, and Apple's own items never move.
- **Nothing stays hidden by accident.** Quit Menu Bar Manager, or if it ever crashes, every item comes back.
- **Notched MacBooks.** On a screen with a notch, your Shown items step aside while the Hidden ones are out, so they don't vanish behind the notch. Click again and everything goes back. External displays simply add the Hidden items to the bar.
- **Hides again by itself** after the delay you choose, and waits while a menu is open.
- **Show from anywhere.** A shortcut (⌃⌥⌘B, changeable), hovering over the chevron, or scrolling on the menu bar.
- **Right-click the chevron** for Settings, Help, updates, About and Quit.
- **Works with your other apps.** `menubarmanager://toggle`, `show`, `hide` and `settings` links for scripts and Shortcuts, a menu in ToolHUD, and its shortcut listed in ShortcutsLens.
- **Settings sync.** Sections and options follow you to your other Macs through iCloud Drive.
- **Help built in.** ⌘? or the ? button in Settings.

## Updates

Menu Bar Manager checks GitHub for new versions. In Settings › General choose whether it installs them automatically (it waits until the hidden items are put away and your Mac is idle), only lets you know, or never checks.

## Building

```bash
./build.sh
```

Builds with Swift Package Manager, signs, and installs `/Applications/MenuBarManager.app`. Unit tests: `swift test`. The app's own checks: `tools/selftest.sh`.

## License

© 2026 Steve Manke. All rights reserved.
