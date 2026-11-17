import AppKit

enum MenuSection: String, CaseIterable, Identifiable, Codable {
    case shown, hidden, alwaysHidden
    var id: String { rawValue }
    var title: String {
        switch self {
        case .shown: "Shown"
        case .hidden: "Hidden"
        case .alwaysHidden: "Always Hidden"
        }
    }
}

/// Hides menu bar items by app. Each app's items share one section: macOS 27
/// hides by app, not by item. The hiding itself is BarRestriction, which is
/// instant and is dropped by macOS if Menu Bar Manager quits or crashes.
@Observable
final class AppHider {
    static let shared = AppHider()

    private(set) var sections: [String: MenuSection]

    private let defaults = UserDefaults.standard
    private static let sectionsKey = "appSections"
    private let restriction = BarRestriction()
    private var launchObserver: NSObjectProtocol?
    private var quitObserver: NSObjectProtocol?
    private var lastState = (expanded: false, includingAlwaysHidden: false)
    /// Shown apps taken off the bar while the hidden ones are out on a notched
    /// screen, so the hidden ones have room right of the notch.
    var swappedOut: Set<String> = []
    /// Shown apps stepping aside so the chevron fits when the Mac's only screen has a
    /// notch. Never used with another display connected; cleared whenever there may be
    /// room again (a screen or section change, an app quitting), then rebuilt as needed.
    /// Settings › Items marks these apps.
    var setAside: Set<String> = []

    /// Brings every set-aside app back. MenuBarController sets one aside again if the
    /// chevron still doesn't fit.
    func releaseSetAside() {
        guard !setAside.isEmpty else { return }
        setAside = []
        reapply()
    }
    /// Where each app's leftmost item was last drawn, for listing apps in bar order
    /// even while they're hidden.
    private(set) var lastSeenX: [String: CGFloat] = [:]

    func noteDrawn(_ items: [DrawnItem]) {
        var seen: [String: CGFloat] = [:]
        for item in items { if let id = item.bundleID { seen[id] = min(seen[id] ?? .infinity, item.frame.minX) } }
        lastSeenX.merge(seen) { _, new in new }
    }

    private init() {
        let raw = defaults.dictionary(forKey: Self.sectionsKey) as? [String: String] ?? [:]
        sections = raw.compactMapValues(MenuSection.init(rawValue:))
        // A newly launched app isn't in the allow-list yet, so it would be hidden:
        // rebuild the restriction to include it.
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reapply() }
        }
        // An app quitting frees room on the bar.
        quitObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.releaseSetAside() }
        }
    }

    var isAvailable: Bool { BarRestriction.isAvailable }

    func section(for bundleID: String) -> MenuSection { sections[bundleID] ?? .shown }

    /// Apps whose section just came from another Mac (settings sync). Their items may sit on
    /// the other side of the chevron here, so their place in the bar doesn't change their
    /// section until the two agree again or the user picks a section here.
    var adopted: Set<String> = []

    /// Re-reads the sections after another Mac's settings were adopted.
    func reload() {
        let raw = defaults.dictionary(forKey: Self.sectionsKey) as? [String: String] ?? [:]
        let new = raw.compactMapValues(MenuSection.init(rawValue:))
        guard new != sections else { return }
        adopted.formUnion(Set(new.keys).union(sections.keys).filter { new[$0] != sections[$0] })
        sections = new
        reapply()
    }

    func setSection(_ section: MenuSection, for bundleID: String) {
        adopted.remove(bundleID)
        sections[bundleID] = section
        // A different set of Shown apps needs a fresh look at what fits.
        setAside = []
        defaults.set(sections.mapValues(\.rawValue), forKey: Self.sectionsKey)
        reapply()
    }

    /// Apps whose items are off the bar in this state.
    func appsToHide(expanded: Bool, includingAlwaysHidden: Bool) -> Set<String> {
        (expanded ? swappedOut : setAside).union(sections.compactMap { id, section in
            Self.isOffBar(section, expanded: expanded, includingAlwaysHidden: includingAlwaysHidden) ? id : nil
        })
    }

    /// Whether an app in `section` is off the bar in this state.
    static func isOffBar(_ section: MenuSection, expanded: Bool, includingAlwaysHidden: Bool) -> Bool {
        switch section {
        case .shown: false
        case .hidden: !expanded
        case .alwaysHidden: !includingAlwaysHidden
        }
    }

    func apply(expanded: Bool, includingAlwaysHidden: Bool) {
        lastState = (expanded, includingAlwaysHidden)
        restriction.hide(appsToHide(expanded: expanded, includingAlwaysHidden: includingAlwaysHidden))
    }

    private func reapply() {
        restriction.hide(appsToHide(expanded: lastState.expanded, includingAlwaysHidden: lastState.includingAlwaysHidden))
        restriction.refresh()
    }

    /// Everything back on the bar. Called at quit; a crash does the same on its own.
    func restoreAll() { restriction.release() }
}
