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
        // ⌘-drags in the bar aren't reported to other apps, so watch the drawn order.
        orderTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkOrder() }
        }
    }

    private var orderTimer: Timer?
    private var lastOrder: [String] = []

    /// Syncs sections when the drawn order changes. Expanding or collapsing changes
    /// the order too (items appear and vanish), which is harmless: those apps are
    /// already in the section their side implies.
    private func checkOrder() {
        keepRoomForChevron()
        let drawn = MenuBarItems.drawn()
        let plain = NSScreen.screens.first { $0.safeAreaInsets.top == 0 } ?? NSScreen.screens[0]
        AppHider.shared.noteDrawn(drawn.filter { plain.frame.minX...plain.frame.maxX ~= $0.frame.midX })
        let order = drawn.compactMap(\.bundleID)
        guard order != lastOrder else { return }
        let first = lastOrder.isEmpty
        lastOrder = order
        if !first { syncSectionsFromPositions() }
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
                    _ = command; self?.commandDragEnded()   // ⌘ may already be up when the button is
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

    /// When the bar last changed because of us; positions are unreliable for a while after.
    private var lastChange = Date.distantPast

    func syncSectionsFromPositions() {
        // While apps are swapped out, or while the bar is still settling after a show
        // or hide, items sit in places that say nothing about their sections.
        guard AppHider.shared.swappedOut.isEmpty, Date().timeIntervalSince(lastChange) > 3 else { return }
        let me = Bundle.main.bundleIdentifier
        let drawn = MenuBarItems.drawn()
        // The chevron as drawn; each display has its own copy of the bar, so compare
        // within the display the chevron's copy is on.
        for chevronItem in drawn where chevronItem.bundleID == me {
            let row = drawn.filter { abs($0.frame.minY - chevronItem.frame.minY) < 8 && abs($0.frame.minX - chevronItem.frame.minX) < 4000 }
            var rightOfChevron: [String: Bool] = [:]
            for item in row {
                guard let id = item.bundleID, id != me, !id.hasPrefix("com.apple.") else { continue }
                rightOfChevron[id] = (rightOfChevron[id] ?? false) || item.frame.midX > chevronItem.frame.midX
            }
            let hider = AppHider.shared
            for (id, right) in rightOfChevron {
                let current = hider.section(for: id)
                guard current != .alwaysHidden else { continue }
                let wanted: MenuSection = right ? .shown : .hidden
                if wanted != current { hider.setSection(wanted, for: id) }
            }
            return    // the first copy decides; the bars share one order
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
        lastChange = Date()
        AppHider.shared.swappedOut = shouldSwap() ? shownAppsOnBar() : []
        AppHider.shared.apply(expanded: true, includingAlwaysHidden: includingAlwaysHidden)
        updateChevron()
        scheduleCollapse()
    }

    // MARK: Moving from Settings

    /// Puts an app in a section. Shown and Hidden are places in the bar, so the app's
    /// items are ⌘-dragged across the chevron; Always Hidden is set directly.
    func move(_ bundleID: String, to section: MenuSection) async {
        let hider = AppHider.shared
        guard section != .alwaysHidden else { hider.setSection(.alwaysHidden, for: bundleID); return }
        let wasExpanded = isExpanded
        // The item has to be on the bar to be dragged.
        if hider.section(for: bundleID) == .alwaysHidden { hider.setSection(.hidden, for: bundleID) }
        if !isExpanded { expand() }
        try? await Task.sleep(for: .milliseconds(700))
        _ = await ItemMover.move(bundleID, toShown: section == .shown)
        lastChange = .distantPast
        syncSectionsFromPositions()
        if !wasExpanded { collapse() }
    }

    // MARK: Room for the chevron

    /// On a screen with a notch the chevron can end up behind macOS's overflow. When
    /// that happens (collapsed, bar settled), the narrowest Shown app with a single
    /// item steps aside, on every screen, until the chevron fits. Apps with several
    /// items, like iStat Menus, are never picked.
    private func keepRoomForChevron() {
        guard !isExpanded, Date().timeIntervalSince(lastChange) > 3 else { return }
        let me = Bundle.main.bundleIdentifier
        let drawn = MenuBarItems.drawn()
        let notched = NSScreen.screens.filter { $0.safeAreaInsets.top > 0 }
        let missing = notched.contains { screen in
            let x = screen.frame.minX...screen.frame.maxX
            let onScreen = drawn.filter { x ~= $0.frame.midX }
            return !onScreen.isEmpty && !onScreen.contains { $0.bundleID == me }
        }
        guard missing else { return }
        let hider = AppHider.shared
        var widths: [String: (count: Int, width: CGFloat)] = [:]
        let main = NSScreen.screens.first { $0.safeAreaInsets.top == 0 } ?? NSScreen.screens[0]
        for item in drawn where main.frame.minX...main.frame.maxX ~= item.frame.midX {
            guard let id = item.bundleID, id != me, !id.hasPrefix("com.apple."),
                  hider.section(for: id) == .shown, !hider.setAside.contains(id) else { continue }
            let entry = widths[id] ?? (0, 0)
            widths[id] = (entry.count + 1, entry.width + item.frame.width)
        }
        guard let pick = widths.filter({ $0.value.count == 1 }).min(by: { $0.value.width < $1.value.width })?.key else { return }
        hider.setAside.insert(pick)
        hider.apply(expanded: false, includingAlwaysHidden: false)
        lastChange = Date()
    }

    // MARK: Swap

    /// On a screen with a notch there's rarely room for the hidden items, so while
    /// they're out, the Shown apps step aside (Settings › General, on by default).
    /// While the hidden items are out, the Shown apps step aside on every screen, so
    /// the bar behaves the same everywhere and a notch never crowds the hidden items
    /// out (Settings › General, off by default).
    private func shouldSwap() -> Bool {
        UserDefaults.standard.bool(forKey: "swapOnNotch")
    }

    private func shownAppsOnBar() -> Set<String> {
        let me = Bundle.main.bundleIdentifier
        let hider = AppHider.shared
        return Set(MenuBarItems.drawn().compactMap(\.bundleID).filter {
            $0 != me && !$0.hasPrefix("com.apple.") && hider.section(for: $0) == .shown
        })
    }

    func collapse() {
        isExpanded = false
        showsAlwaysHidden = false
        AppHider.shared.swappedOut = []
        lastChange = Date()
        collapseTimer?.invalidate()
        AppHider.shared.apply(expanded: false, includingAlwaysHidden: false)
        updateChevron()
    }

    func toggle() { isExpanded ? collapse() : expand() }

    @objc private func chevronClicked() {
        syncSectionsFromPositions()
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
