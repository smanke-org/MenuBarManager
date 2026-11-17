import AppKit
import MenuBarManagerKit

/// Self-test for agents: runs the app's real functions, prints PASS or FAIL per check, and
/// quits with exit code 0 or 1. It reads settings but never changes them, and starts no
/// chevron, hiding, shortcut, sync or updater.
///   /Applications/MenuBarManager.app/Contents/MacOS/MenuBarManager --selftest
/// (tools/selftest.sh does this.) Add a check for every story with logic.
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested() {
        guard requested else { return }
        // Print each line at once, so a crash keeps the lines before it.
        setvbuf(stdout, nil, _IOLBF, 0)
        Task {
            try? await Task.sleep(for: .seconds(0.5))

            check("1.10.0 is newer than 1.9.9", Version.isNewer("1.10.0", than: "1.9.9"))
            check("a version is not newer than itself", !UpdateController.isNewer(AppInfo.version, than: AppInfo.version))
            check("About has notes for this version", ReleaseNotes.bundled.contains { $0.version == AppInfo.version },
                  "running \(AppInfo.version)")
            check("Help shows the real shortcut", !Help.resolve("{shortcut}").contains("{"))
            let topics = Set(Help.topics.map(\.id))
            for tab in ["Items", "General", "Appearance"] {
                check("Settings › \(tab)'s ? button has a Help page", topics.contains(Help.topic(forSettingsTab: tab)))
            }
            for key in [AppSettings.Key.sections, AppSettings.Key.autoCollapseDelay, AppSettings.Key.showOnHover,
                        AppSettings.Key.showOnScroll, AppSettings.Key.swapOnNotch, AppSettings.Key.hotKey,
                        AppAppearance.key, "showInDock", UpdatePolicy.key] {
                check("\(key) syncs between Macs", SettingsSync.keys.contains(key))
            }
            check("hidden apps leave the bar when collapsed",
                  hides(["a": .hidden], expanded: false) == ["a"] && hides(["a": .hidden], expanded: true).isEmpty)
            check("Always Hidden apps stay off the bar when expanded", hides(["a": .alwaysHidden], expanded: true) == ["a"])
            check("Shown apps never leave the bar", hides(["a": .shown], expanded: false).isEmpty)
            check("the URL scheme is registered", urlSchemes.contains("menubarmanager"))

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    /// AppHider's rule for which apps are off the bar, on made-up sections.
    private static func hides(_ sections: [String: MenuSection], expanded: Bool) -> Set<String> {
        Set(sections.compactMap { id, section in
            AppHider.isOffBar(section, expanded: expanded, includingAlwaysHidden: false) ? id : nil
        })
    }

    private static var urlSchemes: [String] {
        let types = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] ?? []
        return types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    /// Quits through NSApp.terminate, never exit(), and closes sheets first:
    /// an open sheet refuses terminate, and the run would wait forever.
    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}
