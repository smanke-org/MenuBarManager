# Menu Bar Manager

A menu bar organizer for macOS 27 that hides the menu bar items you don't need behind a chevron, and keeps every item in the section you put it in.

Bundle id: `com.smanke.menubarmanager`

## Replaces
Bartender and Thaw, which misbehave on recent macOS releases. The worst problem: iStat Menus and other apps keep moving themselves into the hidden area.

## Main jobs
1. Click the chevron to show or hide the Hidden section. It collapses again after a delay.
2. In Settings › Items, put each app in **Shown**, **Hidden** or **Always Hidden**.
3. Keep items where they belong. Sections are per app, not per position, so an app in Shown is never hidden, however macOS places its items.

## Data
- App section: bundle id → shown / hidden / alwaysHidden (macOS 27 hides by app, so all of an app's items share a section)
- Settings: auto-collapse delay, global shortcut, reveal on hover, reveal on scroll, show drop-down bar (auto / always / never)

## Shape
A menu bar app with one item of its own, the chevron. Hiding uses MenuBarAgent's own allow-list mode (a private MenuBarClientCore assertion), held by a helper process: instant, and dropped by macOS if the app quits or crashes. The old wide-divider trick does nothing on macOS 27. Runs from /Applications (the chevron hides itself otherwise). macOS 27 or later. Local data. Works offline. No accounts.

## System hooks
Global shortcut (with the shortcut editor), Accessibility for listing menu bar items in Settings, login item, `menubarmanager` CLI and MCP, ToolHUD menu hub, ShortcutsLens hotkey report. Standard set: Show in Dock and Show in menu bar checkboxes, appearance switch, Help, About, updater, Settings that scrolls and can be resized.

## Reference
Bartender and Thaw, for their behavior only. Never named in the repo.

## Look
Native, with the system accent color (decided by the agent).

## Not in version one
- Per-item custom icons, spacing or tint
- Rules that show an item based on conditions (battery, Wi-Fi, app running)
- Searching menu bar items
