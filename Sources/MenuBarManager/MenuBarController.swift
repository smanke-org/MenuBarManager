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

    static let hiddenLength: CGFloat = CGFloat(Double(ProcessInfo.processInfo.environment["APP_HIDDEN_LENGTH"] ?? "") ?? 10_000)
    static let dividerLength: CGFloat = 1

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

        divider = bar.statusItem(withLength: NSStatusItem.variableLength)
        divider.button?.setAccessibilityLabel("Menu Bar Manager divider")
        divider.autosaveName = "MenuBarManager.divider"
        divider.behavior = []

        alwaysDivider = bar.statusItem(withLength: NSStatusItem.variableLength)
        alwaysDivider.button?.setAccessibilityLabel("Menu Bar Manager Always Hidden divider")
        alwaysDivider.autosaveName = "MenuBarManager.alwaysDivider"
        alwaysDivider.behavior = []

        // macOS 27 drops an item that is too wide to fit when it is first placed,
        // so the dividers start narrow and grow once they have a place in the bar.
        isExpanded = true
        showsAlwaysHidden = true
        apply()
        Task { [self] in
            try? await Task.sleep(for: .seconds(1))
            if let target = ProcessInfo.processInfo.environment["APP_DEBUG_PLACE_LEFT_OF"] {
                await placeOwnItems(leftOf: target)
            }
            collapse()
        }

        if let path = ProcessInfo.processInfo.environment["APP_DEBUG_DUMP"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
                let lines = ["trusted=\(AXIsProcessTrusted()) items=\(MenuBarItems.all().map(\.identity))"] + [("chevron", chevron), ("divider", divider), ("always", alwaysDivider)].map { name, item in
                    "\(name) visible=\(item.isVisible) length=\(item.length) frame=\(item.button?.window?.frame ?? .zero)"
                }
                try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
            }
        }
    }

    static let chevronIdentity = "com.smanke.menubarmanager/Menu Bar Manager"
    static let dividerIdentity = "com.smanke.menubarmanager/Menu Bar Manager divider"
    static let alwaysIdentity = "com.smanke.menubarmanager/Menu Bar Manager Always Hidden divider"

    /// Puts the chevron left of the item with `identity`, then the divider and the
    /// Always Hidden divider left of it, in that order. Runs while expanded, when
    /// the dividers are 1 pt wide.
    func placeOwnItems(leftOf identity: String) async -> Bool {
        func find(_ id: String) -> MenuBarItem? { MenuBarItems.all().first { $0.identity == id } }
        let plan = [(Self.chevronIdentity, identity), (Self.dividerIdentity, Self.chevronIdentity), (Self.alwaysIdentity, Self.dividerIdentity)]
        for (mover, target) in plan {
            guard let item = find(mover), let anchor = find(target) else { return false }
            if ItemMover.isPlaced(mover, .leftOf, of: target), abs(item.frame.maxX - anchor.frame.minX) < 4 { continue }
            guard await ItemMover.move(item, .leftOf, of: anchor) else {
                NSLog("Menu Bar Manager: could not move \(mover) left of \(target)")
                return false
            }
        }
        return true
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
        // macOS 27 never places fixed-length items, or items with nothing drawn in
        // them, so each divider is a variable-length item showing a blank image.
        Self.setWidth(isExpanded ? Self.dividerLength : Self.hiddenLength, of: divider)
        Self.setWidth(showsAlwaysHidden ? Self.dividerLength : Self.hiddenLength, of: alwaysDivider)
        guard let button = chevron.button else { return }
        let name = isExpanded ? "chevron.right" : "chevron.left"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: isExpanded ? "Hide items" : "Show hidden items")
        image?.isTemplate = true
        button.image = image?.withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
        // A fixed name, so the chevron keeps one identity in both states.
        button.setAccessibilityLabel("Menu Bar Manager")
        button.toolTip = isExpanded ? "Hide items" : "Show hidden items\nOption-click to show Always Hidden items too"
    }

    private static func setWidth(_ width: CGFloat, of item: NSStatusItem) {
        item.button?.image = NSImage(size: NSSize(width: width, height: 16), flipped: false) { _ in true }
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
