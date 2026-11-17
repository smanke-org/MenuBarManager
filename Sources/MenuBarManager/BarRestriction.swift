import AppKit

/// Hides apps' menu bar items instantly, with MenuBarAgent's own allow-list mode
/// (MBAssessmentModeAssertion in the private MenuBarClientCore framework). While the
/// assertion is active, only the listed apps and system items stay in the bar.
///
/// The process holding the assertion loses its own menu bar items, so the chevron
/// would hide itself. The assertion is therefore held by a helper: this same binary
/// started with `--hide-helper`. The app sends it one line per change (the bundle
/// IDs to hide, comma-separated; an empty line releases). When the app quits or
/// crashes, the pipe closes, the helper exits, and macOS drops the assertion.
final class BarRestriction {
    static let helperFlag = "--hide-helper"

    private var helperPID: pid_t = 0
    private var input: FileHandle?
    private(set) var hiddenApps: Set<String> = []

    static var isAvailable: Bool {
        dlopen(frameworkPath, RTLD_NOW) != nil && NSClassFromString("MBAssessmentModeAssertion") != nil
    }

    func hide(_ apps: Set<String>) {
        guard apps != hiddenApps else { return }
        hiddenApps = apps
        send(apps.sorted().joined(separator: ","))
    }

    func release() {
        hiddenApps = []
        send("")
    }

    /// Rebuilds the allow-list, for apps launched since the last change.
    func refresh() {
        guard !hiddenApps.isEmpty else { return }
        send(hiddenApps.sorted().joined(separator: ","))
    }

    private func send(_ line: String) {
        if helperPID == 0 || kill(helperPID, 0) != 0 { startHelper() }
        try? input?.write(contentsOf: Data((line + "\n").utf8))
    }

    /// Spawns the helper with responsibility disclaimed. Otherwise macOS counts
    /// it as part of Menu Bar Manager, and the chevron hides along with the rest.
    private func startHelper() {
        let path = Bundle.main.bundleURL.appending(path: "Contents/Helpers/MenuBarManagerHider").path
        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else { return }
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        posix_spawn_file_actions_adddup2(&actions, fds[0], STDIN_FILENO)
        posix_spawn_file_actions_addclose(&actions, fds[1])
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        typealias Disclaim = @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>, Int32) -> Int32
        if let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_spawnattrs_setdisclaim") {
            _ = unsafeBitCast(symbol, to: Disclaim.self)(&attributes, 1)
        }
        var pid: pid_t = 0
        let args = [path, Self.helperFlag]
        var argv: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) } + [nil]
        let result = posix_spawn(&pid, path, &actions, &attributes, &argv, environ)
        argv.forEach { free($0) }
        posix_spawn_file_actions_destroy(&actions)
        posix_spawnattr_destroy(&attributes)
        close(fds[0])
        guard result == 0 else { close(fds[1]); NSLog("Menu Bar Manager: hiding helper failed to start (\(result))"); return }
        signal(SIGPIPE, SIG_IGN)
        helperPID = pid
        input = FileHandle(fileDescriptor: fds[1], closeOnDealloc: true)
    }

    // MARK: The helper process

    private static let frameworkPath = "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore"
    /// System items are identified by small numbers; allowing all of them keeps
    /// Clock, Control Center, Wi-Fi and the rest in place.
    private static let allSystemItems = NSArray(array: (0...64).map { NSNumber(value: $0) })
    nonisolated(unsafe) private static var assertion: NSObject?

    static func runHelper() -> Never {
        _ = isAvailable
        DispatchQueue.global().async {
            while let line = readLine(strippingNewline: true) {
                let apps = Set(line.split(separator: ",").map(String.init))
                DispatchQueue.main.async { apply(apps) }
            }
            exit(0)    // the app is gone
        }
        // Exit with the app even if stdin stays open somehow.
        let parent = getppid()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in if getppid() != parent { exit(0) } }
        RunLoop.main.run()
        exit(0)
    }

    private static func apply(_ apps: Set<String>) {
        assertion?.perform(NSSelectorFromString("invalidate"))
        assertion = nil
        guard !apps.isEmpty,
              let configClass = NSClassFromString("MBAssessmentModeConfiguration") as? NSObject.Type,
              let assertionClass = NSClassFromString("MBAssessmentModeAssertion") as? NSObject.Type else { return }

        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let allowed = NSArray(array: running.subtracting(apps).sorted())
        typealias Init = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> AnyObject
        let initSel = NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")
        guard let initIMP = class_getMethodImplementation(configClass, initSel) else { return }
        let blank = configClass.perform(NSSelectorFromString("alloc")).takeUnretainedValue()
        let config = unsafeBitCast(initIMP, to: Init.self)(blank, initSel, allSystemItems, allowed)

        let newAssertion = assertionClass.init()
        typealias Activate = @convention(c) (AnyObject, Selector, AnyObject, @escaping @convention(block) (AnyObject?) -> Void) -> Void
        let activateSel = NSSelectorFromString("activateWithConfiguration:completionHandler:")
        guard let activateIMP = class_getMethodImplementation(assertionClass, activateSel) else { return }
        unsafeBitCast(activateIMP, to: Activate.self)(newAssertion, activateSel, config) { error in
            if let error { NSLog("Menu Bar Manager helper: hiding failed: \(error)") }
        }
        assertion = newAssertion
    }
}
