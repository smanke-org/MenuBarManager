import AppKit

/// While macOS holds any menu bar restriction (the only way to hide items on macOS 27),
/// it also blocks Notification Center: clicking the Clock does nothing. So a click on the
/// Clock is held back, hiding is lifted, and the click is sent again. Hiding comes back
/// once Notification Center closes (or if it never opens).
final class ClockPassThrough {
    static let shared = ClockPassThrough()

    private var tap: CFMachPort?
    private var clockFrames: [CGRect] = []
    private var refreshTimer: Timer?
    private var watchTimer: Timer?
    private var swallowNextUp = false
    /// Marks the clicks we send again, so the tap lets them through.
    private static let marker: Int64 = 0x4D42_4D43
    private static let notificationCenterID = "com.apple.notificationcenterui"
    /// How long macOS takes to drop the restriction before the click is sent again.
    private static let releaseDelay: TimeInterval = 0.25

    private init() {}

    func start() {
        refreshClockFrames()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            MainActor.assumeIsolated { ClockPassThrough.shared.tick() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { ClockPassThrough.shared.refreshClockFrames() }
        }
        installTap()
    }

    private func tick() {
        refreshClockFrames()
        if tap == nil { installTap() }    // Accessibility may have been granted since
    }

    private func installTap() {
        guard tap == nil, AXIsProcessTrusted() else { return }
        let mask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                           eventsOfInterest: CGEventMask(mask), callback: { _, type, event, _ in
            // The tap runs on the main run loop.
            nonisolated(unsafe) let event = event
            let swallow = MainActor.assumeIsolated { ClockPassThrough.shared.shouldSwallow(type, event) }
            return swallow ? nil : Unmanaged.passUnretained(event)
        }, userInfo: nil) else { return }
        tap = port
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    private func shouldSwallow(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .leftMouseDown:
            guard event.getIntegerValueField(.eventSourceUserData) != Self.marker,
                  !event.flags.contains(.maskCommand),    // ⌘-drags move the Clock
                  AppHider.shared.isRestricting, !AppHider.shared.isPaused,
                  clockFrames.contains(where: { $0.contains(event.location) }) else { break }
            swallowNextUp = true
            let location = event.location
            DispatchQueue.main.async { self.openNotificationCenter(clickingAt: location) }
            return true
        case .leftMouseUp:
            if swallowNextUp { swallowNextUp = false; return true }
        default: break
        }
        return false
    }

    private func openNotificationCenter(clickingAt location: CGPoint) {
        Diagnostics.note("Clock clicked: hiding lifted for Notification Center")
        AppHider.shared.pauseHiding()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.releaseDelay) {
            MainActor.assumeIsolated {
                Self.click(at: location)
                self.watchNotificationCenter()
            }
        }
    }

    private static func click(at location: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location, mouseButton: .left)
            event?.setIntegerValueField(.eventSourceUserData, value: marker)
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Resumes hiding once Notification Center has closed, or after 2 s if it never opened.
    private func watchNotificationCenter() {
        watchTimer?.invalidate()
        sawNotificationCenter = false
        watchStarted = Date()
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            MainActor.assumeIsolated { ClockPassThrough.shared.checkNotificationCenter() }
        }
    }

    private var sawNotificationCenter = false
    private var watchStarted = Date()

    private func checkNotificationCenter() {
        let open = Self.isNotificationCenterOpen()
        if open { sawNotificationCenter = true }
        guard !open, sawNotificationCenter || Date().timeIntervalSince(watchStarted) > 2 else { return }
        watchTimer?.invalidate()
        watchTimer = nil
        AppHider.shared.resumeHiding()
    }

    private static func isNotificationCenterOpen() -> Bool {
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: notificationCenterID).first?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return false }
        // Its full-screen panel; desktop widgets and banners are smaller.
        let screens = NSScreen.screens.map(\.frame.size)
        return windows.contains { window in
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
            let size = CGSize(width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            return screens.contains { $0 == size }
        }
    }

    /// The Clock on every display, from MenuBarAgent's windows (Accessibility, global
    /// top-left coordinates, the same space as mouse events).
    private func refreshClockFrames() {
        var frames: [CGRect] = []
        for agent in NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent") {
            let app = AXUIElementCreateApplication(agent.processIdentifier)
            for window in Self.children(app, kAXWindowsAttribute) { Self.collectClocks(window, depth: 0, into: &frames) }
        }
        clockFrames = frames
    }

    private static func collectClocks(_ element: AXUIElement, depth: Int, into frames: inout [CGRect]) {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXIdentifier" as CFString, &value) == .success,
           (value as? String) == "com.apple.menuextra.clock", let frame = frame(of: element) {
            frames.append(frame)
            return
        }
        guard depth < 3 else { return }
        for child in children(element, kAXChildrenAttribute) { collectClocks(child, depth: depth + 1, into: &frames) }
    }

    private static func children(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?, size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success else { return nil }
        var point = CGPoint.zero, extent = CGSize.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &point)
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
        return CGRect(origin: point, size: extent)
    }
}
