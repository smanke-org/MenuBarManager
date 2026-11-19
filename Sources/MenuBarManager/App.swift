import AppKit

// MenuBarManager
//   MenuBarManager                      the app
//   MenuBarManager --hide-helper        the hiding helper (BarRestriction); no UI at all
//   APP_SNAPSHOT=<dir> MenuBarManager   save a PNG of every Settings pane, Help and About in light and dark mode, then quit
//   MenuBarManager --selftest           run the self-test and quit with 0 or 1 (tools/selftest.sh)
//   APP_ACCENT=<id> MenuBarManager      run with another accent from Theme.all (UI/Theme.swift)
//   APP_GRID=1 MenuBarManager           draw the 8 pt grid and the layout probes over the windows
//   MENUBARMANAGER_DEBUG=1              development affordances; the log is ~/Library/Logs/MenuBarManager.log

@main
enum Entry {
    static func main() {
        // The same binary doubles as the hiding helper (see BarRestriction).
        if CommandLine.arguments.contains(BarRestriction.helperFlag) {
            BarRestriction.runHelper()    // never returns
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // A menu bar app; it has a Dock icon only if the user turned one on.
        app.setActivationPolicy(AppPresence.showInDock ? .regular : .accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

/// Quits Menu Bar Manager without asking: for quitting itself (installing an update, ending a test).
@MainActor
enum QuitConfirmation {
    private(set) static var confirmed = false

    static func quitNow() {
        confirmed = true
        NSApp.terminate(nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let launchAtLogin = LaunchAtLogin()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Before anything saves a setting: an empty domain means a brand-new install.
        let newInstall = SettingsSync.domainIsEmpty()
        AppAppearance.start()
        SettingsWindow.shared.launchAtLogin = launchAtLogin
        NSApp.mainMenu = makeMainMenu()

        // Snapshots and the self-test run in the foreground, without the chevron, hiding,
        // shortcuts, sync or updates.
        if SelfTest.requested || Snapshot.requested {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
            SelfTest.runIfRequested()
            Snapshot.runIfRequested()
            return
        }
        Diagnostics.note("launch \(AppInfo.displayVersion) from \(Bundle.main.bundlePath)")

        MenuBarController.shared.install()
        ClockPassThrough.shared.start()
        HotKeyCenter.shared.perform = { action in
            switch action {
            case .toggle: MenuBarController.shared.toggle()
            }
        }
        HotKeyCenter.shared.apply()
        // Test hook: APP_TEST_MOVE=<bundle id>=<shown|hidden|alwaysHidden>
        if let spec = ProcessInfo.processInfo.environment["APP_TEST_MOVE"],
           let eq = spec.lastIndex(of: "="), let section = MenuSection(rawValue: String(spec[spec.index(after: eq)...])) {
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MenuBarController.shared.move(String(spec[..<eq]), to: section)
            }
        }
        ShortcutsLensReport.start({ HotKeyCenter.shared.reportedShortcuts }) { id, keyCode, modifiers in
            HotKeyCenter.shared.change(id: id, keyCode: UInt32(keyCode), carbonModifiers: UInt32(modifiers))
        }
        // ToolHUD can show the chevron's menu as a submenu of its own; the chevron stays.
        MenuHub.shared.start(menu: { MenuBarController.shared.menu() },
                             icon: { MenuBarController.shared.chevronImage })

        launchAtLogin.enableOnFirstRun()
        // An automatic update quits and relaunches, which would pull the Hidden items away
        // from under the user.
        AutoUpdater.shared.appBusyReason = {
            MenuBarController.shared.isExpanded ? "the Hidden items are showing" : nil
        }
        SettingsSync.shared.onApply = {
            AppSettings.shared.reload()
            AppHider.shared.reload()
            ThemeStore.shared.reload()
            HotKeyCenter.shared.apply()
            MenuHub.shared.reload()
        }
        if newInstall { SettingsSync.shared.adoptOnNewInstall() }
        SettingsSync.shared.start()
        AutoUpdater.shared.start(newInstall: newInstall)

        // Listing other apps' menu bar items in Settings needs Accessibility.
        if !AXIsProcessTrusted() {
            AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
    }

    /// The app menu, Window and Help menus, for while the app is in front (Settings, Help or
    /// About open, or a Dock icon).
    private func makeMainMenu() -> NSMenu {
        let mainMenu = AppPresence.mainMenu(appName: AppInfo.name, settingsTitle: "Settings…",
                                            target: self, settings: #selector(showSettings))
        // Right below About in the app menu.
        let otherApps = NSMenuItem(title: "Our other apps…", action: #selector(showOtherApps), keyEquivalent: "")
        otherApps.target = self
        mainMenu.items.first?.submenu?.insertItem(otherApps, at: 1)
        // Edit, so the Help search field takes ⌘X, ⌘C, ⌘V and ⌘A.
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        mainMenu.insertItem(editItem, at: 1)
        // Help menu, with the standard ⌘? (macOS adds its search field).
        let helpItem = NSMenuItem()
        let help = NSMenu(title: "Help")
        let helpOpen = NSMenuItem(title: "Menu Bar Manager Help", action: #selector(showHelp), keyEquivalent: "?")
        helpOpen.target = self
        help.addItem(helpOpen)
        helpItem.submenu = help
        mainMenu.addItem(helpItem)
        NSApp.helpMenu = help
        return mainMenu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Quitting asks first while "Ask before quitting" is on — not when macOS is logging out,
    /// restarting or shutting down, and not when Menu Bar Manager quits itself to install an update.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let systemQuit = NSAppleEventManager.shared().currentAppleEvent?
            .attributeDescriptor(forKeyword: AEKeyword(kAEQuitReason)) != nil
        guard AppSettings.shared.confirmQuit, !QuitConfirmation.confirmed, !systemQuit,
              !SelfTest.requested, !Snapshot.requested else { return .terminateNow }

        // A menu bar app needs to be a regular one for the alert to come to the front; the
        // old policy goes back a runloop turn later, once the alert is gone.
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { DispatchQueue.main.async { NSApp.setActivationPolicy(previousPolicy) } }

        let alert = NSAlert()
        alert.messageText = "Quit Menu Bar Manager?"
        alert.informativeText = "Every hidden menu bar item comes back, and the chevron and its shortcut go away until you open Menu Bar Manager again."
        // Quit has no key, so Return does nothing: quitting takes a click, never a stray keystroke.
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Quit").keyEquivalent = ""
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"
        alert.layout()
        NSApp.activate(ignoringOtherApps: true)
        alert.window.makeKeyAndOrderFront(nil)

        guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        if alert.suppressionButton?.state == .on { AppSettings.shared.confirmQuit = false }
        return .terminateNow
    }

    /// Every item back on the bar; the self-test's result becomes the exit code.
    func applicationWillTerminate(_ notification: Notification) {
        AppHider.shared.restoreAll()
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }

    /// The Dock icon's right-click menu, when "Show in Dock" is on.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        AppPresence.dockMenu(title: "Settings…", target: self, action: #selector(showSettings))
    }

    /// Clicking the Dock icon, or opening the app again from Applications or Spotlight,
    /// opens Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    /// `menubarmanager://` URLs (from ToolHUD, Shortcuts or a script): `toggle`, `show`
    /// (the Hidden items), `hide` and `settings`.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "menubarmanager" {
            let action = url.host() ?? url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let bar = MenuBarController.shared
            switch action {
            case "toggle": bar.toggle()
            case "show": if !bar.isExpanded { bar.expand() }
            case "hide": if bar.isExpanded { bar.collapse() }
            case "settings": showSettings()
            default: Diagnostics.note("url: unknown action \(action)")
            }
        }
    }

    @objc func showSettings() { SettingsWindow.shared.show() }

    @objc func showHelp() { HelpWindow.shared.show() }

    /// The app menu's About item (`AppPresence.mainMenu`).
    @objc func showAbout() { AppInfo.showAbout() }

    /// The developer's site, which lists every app.
    @objc func showOtherApps() {
        if let url = URL(string: "https://stevemanke.com/") { NSWorkspace.shared.open(url) }
    }
}
