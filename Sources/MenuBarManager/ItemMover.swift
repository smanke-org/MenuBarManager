import AppKit

/// Moves an app's menu bar items across the chevron with ⌘-drags, the way a
/// person would, so Settings and the menu bar always agree: an app's place in the
/// bar is its section. Positions come from MenuBarAgent (MenuBarItems.drawn), in
/// global top-left coordinates, the same space CGEvent uses.
enum ItemMover {
    /// Drags every item of `bundleID` to the right of the chevron (Shown) or the
    /// left of it (Hidden). Returns false when an item or the chevron can't be found.
    static func move(_ bundleID: String, toShown: Bool) async -> Bool {
        let me = Bundle.main.bundleIdentifier
        // Use the bar on a screen without a notch when there is one: everything fits there.
        let plain = NSScreen.screens.first { $0.safeAreaInsets.top == 0 }
        func onMainBar(_ item: DrawnItem) -> Bool {
            guard let plain else { return true }
            return plain.frame.minX...plain.frame.maxX ~= item.frame.midX
        }
        let saved = CGEvent(source: nil)?.location
        defer { if let saved { CGWarpMouseCursorPosition(saved) } }

        for _ in 0..<8 {    // one item per pass; positions change after each drag
            let drawn = MenuBarItems.drawn().filter(onMainBar)
            guard let chevron = drawn.first(where: { $0.bundleID == me }) else { return false }
            let wrongSide = drawn.filter {
                $0.bundleID == bundleID && (toShown ? $0.frame.midX < chevron.frame.midX : $0.frame.midX > chevron.frame.midX)
            }
            guard let item = toShown ? wrongSide.last : wrongSide.first else {
                return drawn.contains { $0.bundleID == bundleID }
            }
            let start = CGPoint(x: item.frame.midX, y: item.frame.midY)
            let end = CGPoint(x: toShown ? chevron.frame.maxX + 3 : chevron.frame.minX + 3, y: chevron.frame.midY)
            await drag(from: start, to: end)
            try? await Task.sleep(for: .milliseconds(500))
        }
        return false
    }

    private static func drag(from start: CGPoint, to end: CGPoint) async {
        let source = CGEventSource(stateID: .combinedSessionState)
        func post(_ type: CGEventType, _ point: CGPoint) {
            let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
        post(.mouseMoved, start)
        try? await Task.sleep(for: .milliseconds(60))
        post(.leftMouseDown, start)
        try? await Task.sleep(for: .milliseconds(150))
        for i in 1...15 {
            let t = CGFloat(i) / 15
            post(.leftMouseDragged, CGPoint(x: start.x + (end.x - start.x) * t, y: start.y))
            try? await Task.sleep(for: .milliseconds(20))
        }
        try? await Task.sleep(for: .milliseconds(150))
        post(.leftMouseUp, end)
    }
}
