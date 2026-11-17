import AppKit

/// Hides apps' menu bar items instantly, with MenuBarAgent's own allow-list mode
/// (MBAssessmentModeAssertion in the private MenuBarClientCore framework). While the
/// assertion is active, only the listed apps and system items stay in the bar.
/// Invalidating it brings everything back at once, with no restart. The assertion
/// belongs to this process, so if Menu Bar Manager quits or crashes, macOS drops it
/// and every item returns.
final class BarRestriction {
    private var assertion: NSObject?
    private(set) var hiddenApps: Set<String> = []

    private static let loaded: Bool = dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore", RTLD_NOW) != nil
    static var isAvailable: Bool {
        loaded && NSClassFromString("MBAssessmentModeAssertion") != nil && NSClassFromString("MBAssessmentModeConfiguration") != nil
    }

    /// System items are identified by small numbers; allowing all of them keeps
    /// Clock, Control Center, Wi-Fi and the rest in place.
    private static let allSystemItems = NSArray(array: (0...64).map { NSNumber(value: $0) })

    /// Hides exactly `apps`. An empty set releases the restriction.
    func hide(_ apps: Set<String>) {
        guard apps != hiddenApps || (assertion == nil && !apps.isEmpty) else { return }
        release()
        hiddenApps = apps
        guard !apps.isEmpty, Self.isAvailable,
              let configClass = NSClassFromString("MBAssessmentModeConfiguration") as? NSObject.Type,
              let assertionClass = NSClassFromString("MBAssessmentModeAssertion") as? NSObject.Type else { return }

        let allowed = NSArray(array: Self.knownApps().subtracting(apps).sorted())
        typealias Init = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> AnyObject
        let initSel = NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")
        guard let initIMP = class_getMethodImplementation(configClass, initSel) else { return }
        let blank = configClass.perform(NSSelectorFromString("alloc")).takeUnretainedValue()
        let config = unsafeBitCast(initIMP, to: Init.self)(blank, initSel, Self.allSystemItems, allowed)

        let newAssertion = assertionClass.init()
        typealias Activate = @convention(c) (AnyObject, Selector, AnyObject, @escaping @convention(block) (AnyObject?) -> Void) -> Void
        let activateSel = NSSelectorFromString("activateWithConfiguration:completionHandler:")
        guard let activateIMP = class_getMethodImplementation(assertionClass, activateSel) else { return }
        unsafeBitCast(activateIMP, to: Activate.self)(newAssertion, activateSel, config) { error in
            if let error { NSLog("Menu Bar Manager: hiding failed: \(error)") }
        }
        assertion = newAssertion
    }

    func release() {
        assertion?.perform(NSSelectorFromString("invalidate"))
        assertion = nil
        hiddenApps = []
    }

    /// Every app that might own a menu bar item: running apps, plus agents that
    /// launch later are added when they launch (AppHider listens for that).
    static func knownApps() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }
}
