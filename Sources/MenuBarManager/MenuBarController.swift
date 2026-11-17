import AppKit

/// The chevron in the menu bar. Clicking it switches the Hidden apps on or off
/// (AppHider); Option-click also switches the Always Hidden apps on.
///
/// macOS 27 ignores the old divider trick (a very wide status item no longer
/// pushes items off screen), so there are no dividers: hiding works by app.
@Observable
final class MenuBarController {
    static let shared = MenuBarController()

    private(set) var isExpanded = false
    private(set) var showsAlwaysHidden = false

    /// Seconds before an expanded bar collapses on its own; 0 = never.
    var autoCollapseDelay: TimeInterval {
        get { UserDefaults.standard.object(forKey: "autoCollapseDelay") as? Double ?? 30 }
        set { UserDefaults.standard.set(newValue, forKey: "autoCollapseDelay"); scheduleCollapse() }
    }

    private var chevron: NSStatusItem!
    private var collapseTimer: Timer?

    private init() {}

    func install() {
        guard chevron == nil else { return }
        chevron = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        chevron.autosaveName = "MenuBarManager.chevron"
        chevron.behavior = []
        if let button = chevron.button {
            button.target = self
            button.action = #selector(chevronClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateChevron()
        AppHider.shared.apply(expanded: false, includingAlwaysHidden: false)
    }

    // MARK: Showing and hiding

    func expand(includingAlwaysHidden: Bool = false) {
        isExpanded = true
        showsAlwaysHidden = includingAlwaysHidden
        AppHider.shared.apply(expanded: true, includingAlwaysHidden: includingAlwaysHidden)
        updateChevron()
        scheduleCollapse()
    }

    func collapse() {
        isExpanded = false
        showsAlwaysHidden = false
        collapseTimer?.invalidate()
        AppHider.shared.apply(expanded: false, includingAlwaysHidden: false)
        updateChevron()
    }

    func toggle() { isExpanded ? collapse() : expand() }

    @objc private func chevronClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else if event?.modifierFlags.contains(.option) == true {
            isExpanded && showsAlwaysHidden ? collapse() : expand(includingAlwaysHidden: true)
        } else {
            toggle()
        }
    }

    private func updateChevron() {
        guard let button = chevron?.button else { return }
        let image = NSImage(systemSymbolName: isExpanded ? "chevron.right" : "chevron.left", accessibilityDescription: nil)
        image?.isTemplate = true
        button.image = image?.withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
        // A fixed name, so the chevron keeps one identity in both states.
        button.setAccessibilityLabel("Menu Bar Manager")
        button.toolTip = isExpanded
            ? "Hide items"
            : "Show hidden items\nOption-click to show Always Hidden items too"
    }

    // MARK: Collapsing on its own

    private func scheduleCollapse() {
        collapseTimer?.invalidate()
        let delay = autoCollapseDelay
        guard isExpanded, delay > 0 else { return }
        collapseTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.collapseUnlessAMenuIsOpen() }
        }
    }

    /// Don't pull an item out from under its own open menu.
    private func collapseUnlessAMenuIsOpen() {
        if MenuBarItems.isAnyMenuOpen() { scheduleCollapse() } else { collapse() }
    }

    // MARK: Menu

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Menu Bar Manager", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        chevron.menu = menu
        chevron.button?.performClick(nil)
        chevron.menu = nil
    }

    @objc func openSettings() {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
