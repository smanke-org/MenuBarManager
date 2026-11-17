import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A keyboard shortcut: a key code plus Carbon modifier flags, and how to show it.
struct HotKey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var display: String

    static let controlOptionCommand = UInt32(controlKey | optionKey | cmdKey)

    init(keyCode: UInt32, modifiers: UInt32, display: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.display = display
    }

    /// Builds one from a key press, if it has at least one of ⌘ ⌥ ⌃ — a bare key would
    /// steal ordinary typing from every app.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.intersection([.command, .option, .control]).isEmpty || Self.isFunctionKey(Int(event.keyCode)) else { return nil }
        keyCode = UInt32(event.keyCode)
        modifiers = Self.carbon(flags)
        display = Self.symbols(flags) + Self.name(for: event)
    }

    /// Builds one from a key code and Carbon modifiers (ShortcutsLens's Change Shortcut), named
    /// the way a key press would be in the current keyboard layout. Nil without ⌘ ⌥ or ⌃.
    init?(keyCode: Int, carbonModifiers: Int) {
        let mods = UInt32(carbonModifiers) & UInt32(controlKey | optionKey | shiftKey | cmdKey)
        guard (0...127).contains(keyCode), mods & UInt32(controlKey | optionKey | cmdKey) != 0 || Self.isFunctionKey(keyCode) else { return nil }
        var flags: NSEvent.ModifierFlags = []
        if mods & UInt32(controlKey) != 0 { flags.insert(.control) }
        if mods & UInt32(optionKey) != 0 { flags.insert(.option) }
        if mods & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if mods & UInt32(cmdKey) != 0 { flags.insert(.command) }
        self.keyCode = UInt32(keyCode)
        modifiers = mods
        display = Self.symbols(flags) + Self.name(keyCode: keyCode, characters: Self.layoutCharacter(keyCode))
    }

    /// Whether a key press is this shortcut.
    func matches(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        UInt32(keyCode) == self.keyCode
            && Self.carbon(flags.intersection([.command, .option, .control, .shift])) == modifiers
    }

    /// For showing the shortcut beside a menu item.
    var menuKeyEquivalent: (key: String, mask: NSEvent.ModifierFlags) {
        var mask: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { mask.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { mask.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { mask.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { mask.insert(.command) }
        let key = display.drop(while: { "⌃⌥⇧⌘".contains($0) }).lowercased()
        return (key.count == 1 ? key : "", mask)
    }

    /// F1–F20 may stand alone: no app types with them.
    static func isFunctionKey(_ code: Int) -> Bool { fKeys[code] != nil }

    static func carbon(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }

    static func symbols(_ flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }

    private static func name(for event: NSEvent) -> String {
        name(keyCode: Int(event.keyCode), characters: event.charactersIgnoringModifiers)
    }

    static func name(keyCode code: Int, characters: String?) -> String {
        if let f = fKeys[code] { return "F\(f)" }
        switch code {
        case kVK_Return: return "↩"
        case kVK_Space: return "Space"
        case kVK_Escape: return "⎋"
        case kVK_Tab: return "⇥"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        default: return (characters ?? "?").uppercased()
        }
    }

    /// What the key types with no modifiers in the current layout ("t" for kVK_ANSI_T on QWERTY).
    static func layoutCharacter(_ keyCode: Int, shift: Bool = false) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return data.withUnsafeBytes { raw -> String? in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var dead: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), shift ? UInt32(shiftKey >> 8) & 0xFF : 0, UInt32(LMGetKbdType()),
                                        OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &length, &chars)
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }

    /// Key code → F-key number. A table, not a range: the codes are scattered (F1 is 122,
    /// F20 is 90).
    static let fKeys: [Int: Int] = {
        let codes = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
                     kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]
        return Dictionary(uniqueKeysWithValues: codes.enumerated().map { ($1, $0 + 1) })
    }()
}


/// Global shortcuts. Menu Bar Manager has one: show or hide the Hidden apps.
@MainActor
final class HotKeyCenter {
    enum Action: Hashable, CaseIterable {
        case toggle
    }

    static let shared = HotKeyCenter()
    var perform: ((Action) -> Void)?

    private var refs: [EventHotKeyRef] = []
    private var handlerInstalled = false
    private static let defaultsKey = "hotKey.toggle"
    /// ⌃⌥⌘B by default.
    static let defaultToggle = HotKey(keyCode: 11, carbonModifiers: controlKey | optionKey | cmdKey)!

    var bindings: [(Action, HotKey)] {
        Action.allCases.compactMap { action in hotKey(for: action).map { (action, $0) } }
    }

    func apply() {
        unregisterAll()
        installHandlerOnce()
        for (index, binding) in bindings.enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x4D42_4D47), id: UInt32(index + 1))   // "MBMG"
            let status = RegisterEventHotKey(binding.1.keyCode, binding.1.modifiers, id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { refs.append(ref) }
            else { NSLog("Menu Bar Manager: shortcut \(binding.1.display) not registered (\(status)), probably taken by another app") }
        }
        ShortcutsLensReport.publish()
    }

    var reportedShortcuts: [ShortcutsLensReport.Shortcut] {
        bindings.map { action, key in
            ShortcutsLensReport.Shortcut(id: "toggle", title: title(of: action), keyCode: Int(key.keyCode), carbonModifiers: Int(key.modifiers), category: "Menu Bar")
        }
    }

    /// ShortcutsLens "Change Shortcut". Returns nil on success, else a message.
    func change(id: String, keyCode: UInt32, carbonModifiers: UInt32) -> String? {
        guard id == "toggle" else { return "Menu Bar Manager has no shortcut called \(id)." }
        guard let key = HotKey(keyCode: Int(keyCode), carbonModifiers: Int(carbonModifiers)) else {
            return "A shortcut needs ⌘, ⌥ or ⌃, or an F-key."
        }
        let previous = hotKey(for: .toggle)
        save(key, for: .toggle)
        apply()
        if refs.count < bindings.count {
            save(previous, for: .toggle)
            apply()
            return "\(key.display) is taken by another app."
        }
        return nil
    }

    func hotKey(for action: Action) -> HotKey? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.defaultsKey) != nil else { return Self.defaultToggle }
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return nil }   // cleared
        return try? JSONDecoder().decode(HotKey.self, from: data)
    }

    func save(_ hotKey: HotKey?, for action: Action) {
        let data = hotKey.flatMap { try? JSONEncoder().encode($0) } ?? Data()
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    func title(of action: Action) -> String {
        switch action {
        case .toggle: "Show or Hide Hidden Items"
        }
    }

    func others(using key: HotKey, except action: Action?) -> [Action] {
        bindings.filter { $0.0 != action && $0.1 == key }.map(\.0)
    }

    func isOwnHotKey(_ key: HotKey) -> Bool { bindings.contains { $0.1 == key } }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
    }

    private func installHandlerOnce() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &spec, nil, nil)
    }

    func fire(_ id: UInt32) {
        let list = bindings
        guard id >= 1, Int(id) <= list.count else { return }
        perform?(list[Int(id) - 1].0)
    }
}


nonisolated private func hotKeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ data: UnsafeMutableRawPointer?) -> OSStatus {
    var id = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                   nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    guard status == noErr else { return status }
    let value = id.id
    // Carbon delivers hot keys on the main thread's event loop.
    MainActor.assumeIsolated { HotKeyCenter.shared.fire(value) }
    return noErr
}
