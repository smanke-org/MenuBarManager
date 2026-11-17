import AppKit
import SwiftData
import SwiftUI

// MenuBarManager
//   MenuBarManager                      the app
//   APP_STORE=<file> MenuBarManager     use another database (tests, experiments)
//   APP_SNAPSHOT=<dir> MenuBarManager   save a PNG of every sidebar page and Settings tab in light and dark mode, then quit
//   APP_SEED=1 MenuBarManager           fill an empty /tmp store with sample items (tools/snap.sh)
//   MenuBarManager --selftest           run the self-test on a /tmp store and quit with 0 or 1 (tools/selftest.sh)
//   APP_ACCENT=<id> MenuBarManager      run with another accent from Theme.all (UI/Theme.swift)
//   APP_GRID=1 MenuBarManager           draw the 8 pt grid and the layout probes over the window

@main
enum Entry {
    static func main() {
        // The same binary doubles as the hiding helper (see BarRestriction).
        if CommandLine.arguments.contains(BarRestriction.helperFlag) {
            BarRestriction.runHelper()
        } else {
            MenuBarManagerApp.main()
        }
    }
}

struct MenuBarManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel(container: Store.makeContainer())

    var body: some Scene {
        Window("Menu Bar Manager", id: "main") {
            ContentView()
                .environment(model)
                .themed()
                .overlay { if GridOverlay.enabled { GridOverlay() } }
                .frame(minWidth: 760, minHeight: 480)
        }
        .modelContainer(model.container)
        .defaultSize(width: 1100, height: 720)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Item") { model.addItem() }
                    .keyboardShortcut("n")
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .themed()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Started from a terminal, the process is not a foreground app yet.
        if SelfTest.requested || ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
            return
        }
        // A menu bar app: no Dock icon by default, no window at launch.
        NSApp.setActivationPolicy(.accessory)
        MenuBarController.shared.install()
        // Listing other apps' menu bar items in Settings needs Accessibility.
        if !AXIsProcessTrusted() {
            AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
        DispatchQueue.main.async {
            for window in NSApp.windows where window.identifier?.rawValue.hasPrefix("main") == true { window.close() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// The self-test's result becomes the exit code, after a normal quit.
    func applicationWillTerminate(_ notification: Notification) {
        AppHider.shared.restoreAll()
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}

/// Where the data lives: ~/Library/Application Support/MenuBarManager/MenuBarManager.store
enum Store {
    /// True when APP_STORE points somewhere else (tests, snapshots, seed data).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    static var url: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        let dir = URL.applicationSupportDirectory.appending(path: "MenuBarManager", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "MenuBarManager.store")
    }

    static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: Item.self, configurations: ModelConfiguration(url: url))
        } catch {
            fatalError("Could not open the database at \(url.path): \(error)")
        }
    }
}
