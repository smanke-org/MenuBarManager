import AppKit
import Observation

/// App-wide preferences that Settings binds to (UserDefaults). The hiding settings
/// themselves (sections, hide delay, hover, scroll, notch, shortcut) are read where they're
/// used: AppHider, MenuBarController, HotKeyCenter and GeneralSettings' @AppStorage.
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = AppSettings.store

    /// Where these settings and AppPresence's are kept.
    nonisolated(unsafe) static let store: UserDefaults = .standard

    /// A scratch folder for test runs (`MENUBARMANAGER_DATA_DIR`), so they never reach iCloud.
    nonisolated static var testFolder: URL? {
        guard let dir = ProcessInfo.processInfo.environment["MENUBARMANAGER_DATA_DIR"], !dir.isEmpty else { return nil }
        return URL(fileURLWithPath: dir)
    }

    enum Key {
        static let confirmQuit = "confirmQuit"
        static let sections = "appSections"
        static let autoCollapseDelay = "autoCollapseDelay"
        static let showOnHover = "showOnHover"
        static let showOnScroll = "showOnScroll"
        static let swapOnNotch = "swapOnNotch"
        static let hotKey = "hotKey.toggle"
        static let accent = "appearance.accent"
    }

    /// "Ask before quitting" in General.
    var confirmQuit: Bool {
        didSet { defaults.set(confirmQuit, forKey: Key.confirmQuit) }
    }

    /// Launch at login is switched on once, the first time the app runs from /Applications.
    var didOfferLaunchAtLogin: Bool {
        get { defaults.bool(forKey: "didOfferLaunchAtLogin") }
        set { defaults.set(newValue, forKey: "didOfferLaunchAtLogin") }
    }

    /// Mirrors AppPresence, so Settings can bind to it and the Dock icon follows at once.
    var showInDock: Bool {
        didSet {
            guard showInDock != AppPresence.showInDock else { return }
            AppPresence.showInDock = showInDock
            AppPresence.applyDock(keepInFront: NSApp.keyWindow)
        }
    }

    private init() {
        confirmQuit = defaults.object(forKey: Key.confirmQuit) as? Bool ?? true
        showInDock = AppPresence.showInDock
    }

    /// Re-reads everything after another Mac's settings were adopted.
    func reload() {
        confirmQuit = defaults.object(forKey: Key.confirmQuit) as? Bool ?? true
        if showInDock != AppPresence.showInDock {
            showInDock = AppPresence.showInDock
            AppPresence.applyDock()
        }
    }
}
