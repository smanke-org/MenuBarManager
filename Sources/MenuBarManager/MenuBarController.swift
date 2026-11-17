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
        startWatchingPointer()
    }

    // MARK: Hover and scroll

    private var pointerMonitor: Any?
    private var hoverWork: DispatchWorkItem?
    private var lastScroll = Date.distantPast

    /// Both are off by default (Settings › General). Hover waits 0.3 s on the chevron;
    /// a scroll anywhere over the menu bar toggles (down shows, up hides).
    private func startWatchingPointer() {
        pointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .scrollWheel, .leftMouseUp]) { [weak self] event in
            let type = event.type, deltaY = event.scrollingDeltaY, command = event.modifierFlags.contains(.command)
            MainActor.assumeIsolated {
                if type == .leftMouseUp {
                    if command { self?.commandDragEnded() }
                } else {
                    self?.pointerEvent(type, deltaY: deltaY)
                }
            }
        }
    }

    private func pointerEvent(_ type: NSEvent.EventType, deltaY: CGFloat) {
        let defaults = UserDefaults.standard
        let point = NSEvent.mouseLocation
        if type == .scrollWheel, defaults.bool(forKey: "showOnScroll"), isInMenuBar(point), abs(deltaY) > 2,
           Date().timeIntervalSince(lastScroll) > 0.6 {
            lastScroll = Date()
            if deltaY < 0, !isExpanded { expand() } else if deltaY > 0, isExpanded { collapse() }
        }
        if type == .mouseMoved, defaults.bool(forKey: "showOnHover"), !isExpanded {
            let onChevron = chevron.button?.window?.frame.insetBy(dx: -2, dy: -2).contains(point) ?? false
            if onChevron, hoverWork == nil {
                let work = DispatchWorkItem { [weak self] in
                    self?.hoverWork = nil
                    guard let self, self.chevron.button?.window?.frame.contains(NSEvent.mouseLocation) == true else { return }
                    self.expand()
                }
                hoverWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
            } else if !onChevron {
                hoverWork?.cancel()
                hoverWork = nil
            }
        }
    }

    // MARK: ⌘-drag to arrange

    /// A ⌘-drag in the menu bar may have moved an item across the chevron. Once
    /// macOS has settled the new order, sections follow the positions: an app whose
    /// items are all left of the chevron is Hidden; one with any item right of it is
    /// Shown. Always Hidden apps aren't on the bar, so they keep their section.
    private func commandDragEnded() {
        guard isInMenuBar(NSEvent.mouseLocation) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.syncSectionsFromPositions() }
    }

    func syncSectionsFromPositions() {
        guard let chevronFrame = chevron.button?.window?.frame else { return }
        let me = Bundle.main.bundleIdentifier
        // Only items on the chevron's display; other displays draw their own copy of the bar.
        let screenX = (NSScreen.screens.first { $0.frame.minX...$0.frame.maxX ~= chevronFrame.midX } ?? NSScreen.main)
            .map { $0.frame.minX...$0.frame.maxX } ?? chevronFrame.minX...chevronFrame.maxX
        let items = MenuBarItems.all().filter {
            guard let id = $0.bundleID, id != me, !id.hasPrefix("com.apple.") else { return false }
            return $0.frame.minY < 40 && screenX ~= $0.frame.midX
        }
        var rightOfChevron: [String: Bool] = [:]
        for item in items {
            guard let id = item.bundleID, item.frame.width > 0 else { continue }
            let right = item.frame.midX > chevronFrame.midX
            rightOfChevron[id] = (rightOfChevron[id] ?? false) || right
        }
        let hider = AppHider.shared
        for (id, right) in rightOfChevron {
            let current = hider.section(for: id)
            guard current != .alwaysHidden else { continue }
            let wanted: MenuSection = right ? .shown : .hidden
            if wanted != current { hider.setSection(wanted, for: id) }
        }
    }

    private func isInMenuBar(_ point: NSPoint) -> Bool {
        NSScreen.screens.contains { screen in
            screen.frame.minX...screen.frame.maxX ~= point.x
                && point.y >= screen.frame.maxY - NSStatusBar.system.thickness - 6
        }
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
