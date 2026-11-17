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
    private var lastState = (expanded: false, includingAlwaysHidden: false)
    /// Shown apps taken off the bar while the hidden ones are out on a notched
    /// screen, so the hidden ones have room right of the notch.
    var swappedOut: Set<String> = []
    /// Shown apps stepping aside so the chevron fits on a notched screen. Rebuilt
    /// each launch; they come back when the hidden items are shown.
    var setAside: Set<String> = []
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
    }

    var isAvailable: Bool { BarRestriction.isAvailable }

    func section(for bundleID: String) -> MenuSection { sections[bundleID] ?? .shown }

    func setSection(_ section: MenuSection, for bundleID: String) {
        sections[bundleID] = section
        defaults.set(sections.mapValues(\.rawValue), forKey: Self.sectionsKey)
        reapply()
    }

    /// Apps whose items are off the bar in this state.
    func appsToHide(expanded: Bool, includingAlwaysHidden: Bool) -> Set<String> {
        (expanded ? swappedOut : setAside).union(sections.compactMap { id, section in
            switch section {
            case .shown: nil
            case .hidden: expanded ? nil : id
            case .alwaysHidden: includingAlwaysHidden ? nil : id
            }
        })
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
