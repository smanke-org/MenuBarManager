import AppKit

/// One item in the menu bar.
///
/// On macOS 27 the window server no longer lists status items as separate windows
/// (a MenuBarAgent process draws the bar), so items are read through Accessibility:
/// each app's AXExtrasMenuBar lists its items with their real positions.
struct MenuBarItem: Identifiable, Hashable {
    let pid: pid_t
    let bundleID: String?
    let appName: String
    /// AXDescription, else AXTitle: iStat names each item ("iStat Menus CPU").
    let name: String
    /// Index among the app's own items, to tell apart items with no name.
    let index: Int
    let frame: CGRect

    /// Stable across relaunches: which app, and which of its items.
    var identity: String { "\(bundleID ?? appName)/\(name.isEmpty ? "#\(index)" : name)" }
    var id: String { identity }
}

enum MenuBarItems {
    static func all() -> [MenuBarItem] {
        // Never ask our own process over AX from the main thread: it would wait on itself.
        NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .flatMap(items(of:)).sorted { $0.frame.minX < $1.frame.minX }
    }

    static func items(of app: NSRunningApplication) -> [MenuBarItem] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let bar: AXUIElement = attribute(appElement, "AXExtrasMenuBar"),
              let children: [AXUIElement] = attribute(bar, kAXChildrenAttribute) else { return [] }
        return children.enumerated().compactMap { index, element in
            guard let frame = frame(of: element) else { return nil }
            let description: String = attribute(element, kAXDescriptionAttribute) ?? ""
            let title: String = attribute(element, kAXTitleAttribute) ?? ""
            return MenuBarItem(
                pid: app.processIdentifier, bundleID: app.bundleIdentifier,
                appName: app.localizedName ?? "?",
                name: description.isEmpty ? title : description,
                index: index, frame: frame)
        }
    }

    /// A menu from the menu bar is open.
    static func isAnyMenuOpen() -> Bool {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return false }
        return info.contains { ($0[kCGWindowLayer as String] as? Int) == 101 }
    }

    // MARK: AX helpers

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let position: AXValue = attribute(element, kAXPositionAttribute),
              let size: AXValue = attribute(element, kAXSizeAttribute) else { return nil }
        var point = CGPoint.zero, extent = CGSize.zero
        AXValueGetValue(position, .cgPoint, &point)
        AXValueGetValue(size, .cgSize, &extent)
        return CGRect(origin: point, size: extent)
    }
}
