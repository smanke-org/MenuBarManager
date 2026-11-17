import AppKit

/// Moves menu bar items the way a person does: a ⌘-drag in the menu bar.
/// Every move is checked afterward by reading the item's position again.
enum ItemMover {
    enum Side { case leftOf, rightOf }

    /// Drags `item` so it sits on `side` of `target`. Returns true when the item
    /// is there afterward.
    @discardableResult
    static func move(_ item: MenuBarItem, _ side: Side, of target: MenuBarItem) async -> Bool {
        guard item.identity != target.identity else { return true }
        let start = CGPoint(x: item.frame.midX, y: item.frame.midY)
        // Dropping on the outer quarter of the target puts the item on that side.
        let x = side == .leftOf ? target.frame.minX + 2 : target.frame.maxX - 2
        let end = CGPoint(x: x, y: target.frame.midY)

        let saved = CGEvent(source: nil)?.location
        await drag(from: start, to: end)
        if let saved { CGWarpMouseCursorPosition(saved) }

        try? await Task.sleep(for: .milliseconds(250))
        return isPlaced(item.identity, side, of: target.identity)
    }

    static func isPlaced(_ identity: String, _ side: Side, of targetIdentity: String) -> Bool {
        let items = MenuBarItems.all()
        guard let a = items.first(where: { $0.identity == identity }),
              let b = items.first(where: { $0.identity == targetIdentity }) else { return false }
        return side == .leftOf ? a.frame.maxX <= b.frame.minX + 1 : a.frame.minX >= b.frame.maxX - 1
    }

    private static func drag(from start: CGPoint, to end: CGPoint) async {
        let source = CGEventSource(stateID: .combinedSessionState)
        func post(_ type: CGEventType, _ point: CGPoint) {
            let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
        post(.mouseMoved, start)
        try? await Task.sleep(for: .milliseconds(40))
        post(.leftMouseDown, start)
        try? await Task.sleep(for: .milliseconds(120))
        let steps = 12
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            post(.leftMouseDragged, CGPoint(x: start.x + (end.x - start.x) * t, y: start.y))
            try? await Task.sleep(for: .milliseconds(15))
        }
        try? await Task.sleep(for: .milliseconds(120))
        post(.leftMouseUp, end)
    }
}
