import AppKit

/// The chevron and the two invisible dividers that hide menu bar items.
///
///   [Always Hidden] |alwaysDivider| [Hidden] |divider| (chevron) [Shown]
///
/// A divider hides everything to its left by growing very wide, which pushes those
/// items off the left edge of the screen. Items are never captured or redrawn, so
/// live items such as iStat Menus keep drawing themselves.
@Observable
final class MenuBarController {
    static let shared = MenuBarController()

    static let hiddenLength: CGFloat = 10_000
    static let dividerLength: CGFloat = 0

    private(set) var isExpanded = false
    private(set) var showsAlwaysHidden = false

    /// Seconds before an expanded bar collapses on its own; 0 = never.
    var autoCollapseDelay: TimeInterval {
        get { UserDefaults.standard.object(forKey: "autoCollapseDelay") as? Double ?? 10 }
        set { UserDefaults.standard.set(newValue, forKey: "autoCollapseDelay"); scheduleCollapse() }
    }

    private var chevron: NSStatusItem!
    private var divider: NSStatusItem!
    private var alwaysDivider: NSStatusItem!
    private var collapseTimer: Timer?
    private var clickMonitor: Any?

    private init() {}

    /// Created right to left: each new status item appears left of the previous one
    /// the first time; after that, macOS restores the saved positions (autosaveName).
    func install() {
        guard chevron == nil else { return }
        let bar = NSStatusBar.system

        chevron = bar.statusItem(withLength: NSStatusItem.variableLength)
        chevron.autosaveName = "MenuBarManager.chevron"
        chevron.behavior = []                                // cannot be removed by ⌘-dragging out
        if let button = chevron.button {
            button.target = self
            button.action = #selector(chevronClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        divider = bar.statusItem(withLength: Self.hiddenLength)
        divider.autosaveName = "MenuBarManager.divider"
        divider.behavior = []

        alwaysDivider = bar.statusItem(withLength: Self.hiddenLength)
        alwaysDivider.autosaveName = "MenuBarManager.alwaysDivider"
        alwaysDivider.behavior = []

        apply()
    }

    // MARK: Showing and hiding

    func expand(includingAlwaysHidden: Bool = false) {
        isExpanded = true
        showsAlwaysHidden = includingAlwaysHidden
        apply()
        startWatchingForClicksElsewhere()
        scheduleCollapse()
    }

    func collapse() {
        isExpanded = false
        showsAlwaysHidden = false
        apply()
        stopWatchingForClicksElsewhere()
        collapseTimer?.invalidate()
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

    private func apply() {
        divider.length = isExpanded ? Self.dividerLength : Self.hiddenLength
        alwaysDivider.length = showsAlwaysHidden ? Self.dividerLength : Self.hiddenLength
        guard let button = chevron.button else { return }
        let name = isExpanded ? "chevron.right" : "chevron.left"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: isExpanded ? "Hide items" : "Show hidden items")
        image?.isTemplate = true
        button.image = image?.withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
        button.toolTip = isExpanded ? "Hide items" : "Show hidden items\nOption-click to show Always Hidden items too"
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

    private func startWatchingForClicksElsewhere() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            // Clicks in the menu bar open the items we just showed: keep them.
            let location = NSEvent.mouseLocation
            let inMenuBar = NSScreen.screens.contains { screen in
                location.x >= screen.frame.minX && location.x <= screen.frame.maxX
                    && location.y >= screen.frame.maxY - NSStatusBar.system.thickness - 2
            }
            if !inMenuBar { MainActor.assumeIsolated { self?.collapseUnlessAMenuIsOpen() } }
            _ = event
        }
    }

    private func stopWatchingForClicksElsewhere() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
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

    @objc private func openSettings() {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    // MARK: Positions, for the self-test and the drift checker

    /// Screen x of the dividers' right edges, read from the real windows.
    var dividerFrame: CGRect? { divider.button?.window?.frame }
    var chevronFrame: CGRect? { chevron.button?.window?.frame }
    var alwaysDividerFrame: CGRect? { alwaysDivider.button?.window?.frame }
}
