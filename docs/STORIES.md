# Menu Bar Manager — Stories

## M1 Core loop: hide and show

### S-001 Chevron in the menu bar
As the user, I launch the app and see a chevron in the menu bar.
Acceptance:
- [manual] The chevron stays visible while apps are hidden (app runs from /Applications).
Status: done

### S-002 Click the chevron to show and hide
As the user, I click the chevron to show the Hidden apps' items, and click it again to hide them.
Acceptance:
- [manual] The change is instant, with no blink; Apple's items never move.
- [manual] Option-click also shows Always Hidden apps.
Status: done

### S-003 Collapse automatically
As the user, I wait out the delay I chose and the Hidden items hide again.
Acceptance:
- [manual] Default 30 s, set in Settings › General; it waits while a menu is open.
Status: done

### S-004 Choose each app's section
As the user, I open Settings › Items and pick Shown, Hidden or Always Hidden for each app with menu bar items.
Screens: settings-items
Acceptance:
- [manual] Every app with menu bar items is listed with its icon and name; the choice applies at once.
- [manual] Without Accessibility, the page explains why and opens the right Settings pane.
Status: doing

### S-005 Nothing stays hidden by accident
Acceptance:
- [manual] Quitting or force-quitting the app brings every item back (verified 2026-11-17).
- [manual] An app launched while collapsed is added to the allow-list, so Shown apps stay visible.
Status: done

## M2 Keep items in place

### S-007 iStat stays in Shown
Acceptance:
- [manual] Sections are per app, so iStat in Shown is never hidden; its stale far-left saved positions were rewritten 2026-11-17.
Status: done

## M3 Displays and the notch

### S-009 Make room on a notched screen
As the user on a notched MacBook, I click the chevron and my Shown items step aside so the Hidden ones fit; clicking again puts both back.
Acceptance:
- [manual] Only when expanding from a screen with a notch (pointer's screen); setting in General, on by default (verified 2026-11-17).
Status: done

### S-010 Every display
As the user with external displays, I can use the chevron on each display's menu bar.
Acceptance:
- [manual] Expanding on a display without a notch adds the Hidden items to the bar; Shown items stay (verified 2026-11-17).
Status: done

## M4 Speed

### S-011 Global shortcut
As the user, I press a shortcut to show or hide the Hidden items, and can change it in the shortcut editor.
Acceptance:
- [manual] The default ⌃⌥⌘B works; changing it in the editor takes effect at once; ShortcutsLens can read it.
Status: done

### S-012 Show on hover or scroll
As the user, I hover over an empty part of the menu bar, or scroll on it, to show the Hidden items.
Acceptance:
- [manual] Both are off by default, each has a checkbox, and hovering waits 0.3 s before showing.
Status: done

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
- Dividers and per-item sections: macOS 27 ignores the wide-divider trick and hides only by app.
- Moving items with ⌘-drags to restore drifted ones: not needed when sections are per app.
- Accounts, sync, analytics: single user.
- Capturing item images to redraw them: the cause of the problems with live items like iStat.

## Later
- Per-item spacing, tint and icons.
- Rules that show items based on conditions.
- Searching menu bar items.

### S-016 ⌘-drag across the chevron
As the user, I ⌘-drag an item left of the chevron to hide its app, or right of it to show it.
Acceptance:
- [manual] Sections follow MenuBarAgent's drawn positions (apps' own AX frames go stale on macOS 27).
- [manual] An app with any item right of the chevron stays Shown.
Status: done
