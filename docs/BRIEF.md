# Menu Bar Manager

A menu bar organizer for macOS 27 that hides the menu bar items you don't need behind a chevron, and keeps every item in the section you put it in.

Bundle id: `com.smanke.menubarmanager`

## Replaces
Bartender and Thaw, which misbehave on recent macOS releases. The worst problem: iStat Menus and other apps keep moving themselves into the hidden area.

## Main jobs
1. Click the chevron to show or hide the Hidden section. It collapses again on a click elsewhere or after a timer.
2. Arrange items in Settings by dragging them between **Shown**, **Hidden** and **Always Hidden**.
3. Keep items where they belong. Each item's section is remembered by its app and name. When an item drifts (its app relaunches, it changes width, macOS moves it), it is moved back automatically.

## Data
- MenuBarItem: owning bundle id, item title/identifier, section (shown / hidden / alwaysHidden), order within its section
- Settings: auto-collapse delay, global shortcut, reveal on hover, reveal on scroll, show drop-down bar (auto / always / never)

## Shape
A menu bar app with two items of its own: the chevron and an invisible divider that hides items by growing very wide. A second divider marks off Always Hidden. Items are never captured as images, so iStat and other live items draw themselves. On a notched MacBook, or when the Hidden items don't fit on a display, they appear in a drop-down bar under the menu bar instead. Works on every display. macOS 26 or later. Local data. Works offline. No accounts.

## System hooks
Global shortcut (with the shortcut editor), Accessibility for reading item positions and moving items with simulated ⌘-drags, login item, `menubarmanager` CLI and MCP, ToolHUD menu hub, ShortcutsLens hotkey report. Standard set: Show in Dock and Show in menu bar checkboxes, appearance switch, Help, About, updater, Settings that scrolls and can be resized.

## Reference
Bartender and Thaw, for their behavior only. Never named in the repo.

## Look
Native, with the system accent color (decided by the agent).

## Not in version one
- Per-item custom icons, spacing or tint
- Rules that show an item based on conditions (battery, Wi-Fi, app running)
- Searching menu bar items
