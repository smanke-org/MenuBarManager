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
        Set(sections.compactMap { id, section in
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
        let apps = appsToHide(expanded: lastState.expanded, includingAlwaysHidden: lastState.includingAlwaysHidden)
        restriction.release()
        restriction.hide(apps)
    }

    /// Everything back on the bar. Called at quit; a crash does the same on its own.
    func restoreAll() { restriction.release() }
}
