# Menu Bar Manager — Stories

## M1 Core loop: hide and show

### S-001 Chevron and divider appear at launch
As the user, I launch the app and see a chevron in the menu bar, with an invisible divider to its left.
Screens: menubar-collapsed, menubar-expanded
Acceptance:
- [manual] The chevron appears to the left of the Shown items.
- [self] The divider item exists and sits left of the chevron (checked with CGWindowList).
- [unit] The positions of both items are saved and restored after a relaunch.
UX:
- The chevron points left when collapsed and right when expanded. Hover help: "Show hidden items" or "Hide items".
Status: todo

### S-002 Click the chevron to show and hide
As the user, I click the chevron to show the Hidden items, and click it again to hide them.
Depends: S-001
Acceptance:
- [self] When collapsed, the divider is 10,000 pt wide and every item to its left is off screen.
- [self] When expanded, the divider is 0 pt wide and the Hidden items are on screen.
- [manual] iStat Menus draws live values in both states, with no copied or frozen images.
Status: todo

### S-003 Collapse automatically
As the user, I click anywhere else, or wait out the delay I chose, and the Hidden items hide again.
Depends: S-002
Acceptance:
- [unit] The timer collapses after the delay (default 10 s, 0 = never).
- [self] The bar doesn't collapse while one of its items has its menu open.
Status: todo

### S-004 See every item in Settings
As the user, I open Settings › Items and see every menu bar item, with its icon and app name, grouped into Shown, Hidden and Always Hidden.
Screens: settings-items
Depends: S-001
Acceptance:
- [unit] Items come from CGWindowList (layer 25), each matched to the app that owns it.
- [snap] Three labeled groups, each row showing the item's icon and app name.
- [manual] The first time, the app asks for Accessibility (shown as "Device Control and Data Access" on macOS 27) with an explanation and a button that opens System Settings.
UX:
- Section names are "Shown", "Hidden" and "Always Hidden" everywhere.
Status: todo

### S-005 Drag an item to another section
As the user, I drag an item in Settings › Items into another section, and it moves in the real menu bar.
Depends: S-004
Acceptance:
- [self] The item is moved with a simulated ⌘-drag, and its new position is checked afterward.
- [manual] If the move fails, the row shows "Couldn't move" with a Try Again button.
- [unit] The chosen section is saved under the item's identity (bundle id + title).
Status: todo

### S-006 Always Hidden section
As the user, I put items in Always Hidden so they stay out of the menu bar even when it's expanded.
Depends: S-005
Acceptance:
- [self] A second divider stays 10,000 pt wide at all times.
- [manual] Option-clicking the chevron shows the Always Hidden items too.
Status: todo

## M2 Keep items in place

### S-007 Move drifted items back
As the user, I see iStat Menus stay in Shown after I relaunch it or its width changes.
Depends: S-005
Acceptance:
- [unit] A position check runs on app launch/quit notifications and every 5 seconds. It compares each item's section with the saved section.
- [self] A drifted item is moved back within 2 seconds, then checked.
- [unit] An item that keeps drifting is retried 3 times, then flagged in Settings, not moved forever.
- [manual] Relaunch iStat Menus 5 times: it ends up in Shown every time.
Status: todo

### S-008 Put new items in a default section
As the user, I choose whether items that appear for the first time go into Shown or Hidden.
Depends: S-007
Acceptance:
- [unit] An item without a saved section gets the default section and is moved there once.
Status: todo

## M3 Displays and the notch

### S-009 Drop-down bar
As the user on a notched MacBook, I see Hidden items in a bar under the menu bar when they would fall behind the notch.
Screens: dropdown-bar
Depends: S-002
Acceptance:
- [unit] The available width is the menu bar width minus the app menus and the notch (auxiliaryTopLeftArea).
- [snap] The bar shows each item. Clicking one opens that item's own menu (by clicking it while it is briefly placed on screen).
- [manual] Setting: Drop-down bar = Automatic / Always / Never.
Status: todo

### S-010 Every display
As the user with external displays, I can use the chevron on each display's menu bar.
Depends: S-009
Acceptance:
- [manual] Expanding on a display without a notch shows the items in the menu bar itself when they fit.
Status: todo

## M4 Speed

### S-011 Global shortcut
As the user, I press a shortcut to show or hide the Hidden items, and can change it in the shortcut editor.
Acceptance:
- [manual] The default ⌃⌥⌘B works; changing it in the editor takes effect at once; ShortcutsLens can read it.
Status: todo

### S-012 Show on hover or scroll
As the user, I hover over an empty part of the menu bar, or scroll on it, to show the Hidden items.
Acceptance:
- [manual] Both are off by default, each has a checkbox, and hovering waits 0.3 s before showing.
Status: todo

## M5 System and polish

### S-013 Standard app set
As the user, I get the same standard features as my other apps: Show in Dock and Show in menu bar checkboxes (the chevron stays either way), the appearance switch, Help, About, the updater, Settings that scrolls and can be resized, a login item, and the ToolHUD menu hub.
Acceptance:
- [manual] Each one works as it does in SnagAnything.
Status: todo

### S-014 CLI and MCP
As the user, I run `menubarmanager list`, `show`, `hide` and `move <item> <section>`, or use the same commands over MCP.
Acceptance:
- [self] Each command talks to the running app and returns JSON.
Status: todo

### S-015 App icon
Acceptance:
- [snap] Liquid Glass icon using the shared symbol rule ("Mb").
Status: todo

## Dropped
- Accounts, sync, analytics: single user.
- Capturing item images to redraw them: the cause of the problems with live items like iStat.

## Later
- Per-item spacing, tint and icons.
- Rules that show items based on conditions.
- Searching menu bar items.
