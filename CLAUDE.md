# MenuBarManager

A macOS 27 menu bar app (AppKit app shell, SwiftUI panes). A chevron in the menu bar
shows and hides other apps' menu bar items. Settings live in UserDefaults; there is no
database and no server. Read `docs/BRIEF.md` and `docs/STORIES.md` first.

## Layout

- `Sources/MenuBarManager/` the app.
  - `App.swift`: `Entry` (the `--hide-helper` flag runs `BarRestriction.runHelper()` and nothing else), `AppDelegate` (launch order, app/Edit/Help menus, Ask before quitting, Dock menu, reopen → Settings, `menubarmanager://` URLs, `restoreAll` at quit).
  - The core: `MenuBarController` (the chevron, always visible; left-click toggles, ⌥-click adds Always Hidden, right-click opens `menu()`), `AppHider`, `BarRestriction`, `ItemMover`, `MenuBarItems`, `HotKeys`.
  - Settings: `SettingsWindow` (AppKit tabs Items/General/Appearance; panes fill the window, which is sized in AppKit, scrolls and keeps a dragged size; never let SwiftUI size it), `ItemsSettings`, `GeneralSettings`, `UI/AppearanceSettings` (accent), `SyncUpdateControls`.
  - The standard app set, copied from the user's other apps (JumpFolder is the model; keep them alike): `AppPresence` (Show in Dock; `showInMenuBar` is always true), `AppAppearance`, `AppInfo`, `AboutWindow`, `ReleaseNotes` (add a `bundled` entry for every version), `Help` (Menu Bar Manager's own pages), `MenuHub` (ToolHUD), `MenuIcon`, `LaunchAtLogin`, `SettingsSync` (iCloud Drive; `keys` lists what travels), `UpdateController`/`AutoUpdater`/`UpdateInterval`/`UpdatePolicy`/`UpdateAvailability` (repo smanke-org/MenuBarManager), `Diagnostics` (~/Library/Logs/MenuBarManager.log), `AppSettings` (keys and the few settings Settings binds to).
- `Sources/MenuBarManagerKit/` rules and data logic with no SwiftUI. Tests in `Tests/MenuBarManagerKitTests/`.
- `Package.swift` a Swift package. There is no Xcode project.
- `build.sh` builds, signs, and installs `/Applications/MenuBarManager.app`.
- `Tools/generate_icon.swift` + `Tools/make_icns.sh` render the icon ("Mm", 27, deep rose) into `Resources/AppIcon.icns`.
- `docs/` the brief, the screen index, and the user stories, when they exist.

## Build and check

- Build and install: `./build.sh`. Add `--open` to restart the app with the new build. The build shows warnings; fix them.
- Unit tests: `swift test --scratch-path ~/Library/Developer/MenuBarManager/test-build`.
- Self-test (the app's real functions; reads settings, never changes them): `tools/selftest.sh`. Exit 0 when every check passes. Add a check for every story with logic in `SelfTest.swift`.
- After every UI change, take snapshots and look at them: `tools/snap.sh`.
  It writes `/tmp/MenuBarManager-shots/settings-<tab>-light.png` and `-dark.png` for every Settings pane, plus `help-` and `about-`, then quits. `APP_SNAPSHOT_PAGES=settings,help,about tools/snap.sh` limits the pages.
  For a panel, sheet, or popover, add a capture to `Snapshot.swift` like the Settings loop.
- Snapshots and the self-test start no chevron, hiding, shortcut, sync or updater.
- Then check the grid: `tools/grid-lint.sh` and `swift tools/check-layout.swift /tmp/MenuBarManager-shots/*-layout.json`. Both print PASS.
- A change is done when the build has no errors, the grid checks pass, and you looked at the light and dark snapshots.

## Design rules

- Use Apple's controls and system styles. Only the accent color is custom: `UI/Theme.swift` (`ThemeStore.defaultID`). People change it in Settings › Appearance; System, Light or Dark is in Settings › General (`AppAppearance`).
- Views use `.tint`, `Palette.accent`, `Palette.accentText` (accent-colored text), and `Palette.onAccent` (text on an accent fill). Never hard-code colors, radii, or durations in views.
- Compare accents: add `APP_ACCENT=<id>` to the snapshot command.
- Spacing comes from `Space` in `UI/Grid.swift`, on a 4 pt grid (`tools/grid-lint.sh` skips the standard-set files, which match the other apps). Mark custom pages and cards with `.gridArea` and `.gridProbe`.
- Windows open calm: `.noInitialFocus()` on every window and sheet (no focus ring or selected text on open), `.fitsContent()` on sheets (no scroll bar with nothing to scroll). System scroll bars. Both in `UI/WindowBehavior.swift`.
- Settings: one pane per topic, added in `SettingsTabs.init` (`SettingsWindow.swift`), one grouped Form per pane, with a Help page (`Help.topic(forSettingsTab:)`). Add new panes to `Snapshot.settingsTabs` too.
- US spelling in user-facing text. "Settings", never "Preferences". Never name the reference apps from the brief anywhere.
- Window chrome (title bar, toolbar, sidebar, menus, sheets) stays system. Buttons use system styles, like `.borderedProminent`.
- Colors: `.primary`, `.secondary`, `.tint`, and system colors. Never fixed grays or white for text.
- Every action has a menu bar item and a keyboard shortcut.
- `Label` for icon and text pairs. SF Symbols for icons.
- `ContentUnavailableView` for empty states.
- Liquid Glass belongs to floating controls only, never to content.

## Skills

The bama plugin has a skill for each step: `mac-design` (design rules),
`design-system` (accent and tokens), `layout-grid`, `ux-design`,
`swift-swiftui`, `os-integrations`, `performance`, `build-and-verify`,
`test-mac-app`, `app-icon`, `user-stories`, and `improve-loop`. Use them.

## Git

- Commit after each working change, with a message that says what the user can now do. No Claude attribution.
