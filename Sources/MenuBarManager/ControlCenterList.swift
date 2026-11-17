import Foundation

/// The list behind System Settings › Menu Bar › "Allow in the Menu Bar".
/// macOS keeps it in Control Center's group container, which needs Full Disk Access.
enum ControlCenterList {
    static let url = URL.homeDirectory.appending(path: "Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist")

    static var isReadable: Bool { FileManager.default.isReadableFile(atPath: url.path) }

    static func read() -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    /// Debug: write the list as XML for inspection.
    static func dump(to path: String) {
        guard let plist = read(),
              let xml = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else {
            let error = (try? Data(contentsOf: url)).map { _ in "parse failed" } ?? {
                do { _ = try Data(contentsOf: url); return "?" } catch { return "\(error)" }
            }()
            try? "unreadable: \(error)".write(toFile: path, atomically: true, encoding: .utf8)
            return
        }
        try? xml.write(to: URL(fileURLWithPath: path))
    }
}

extension ControlCenterList {
    /// Sets the "Allow in the Menu Bar" switch for an app. Returns false when the app
    /// isn't in the list or the file can't be written.
    ///
    /// trackedApplications is a nested binary plist: an array that alternates keys
    /// ({bundle: {_0: id}}) and values ({location, menuItemLocations, isAllowed}).
    @discardableResult
    static func setAllowed(_ allowed: Bool, bundleID: String) -> Bool {
        guard var plist = read(),
              let data = plist["trackedApplications"] as? Data,
              var tracked = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [Any] else { return false }
        var changed = false
        for i in stride(from: 0, to: tracked.count - 1, by: 2) {
            guard let key = tracked[i] as? [String: Any],
                  let bundle = key["bundle"] as? [String: Any],
                  bundle["_0"] as? String == bundleID,
                  var value = tracked[i + 1] as? [String: Any] else { continue }
            value["isAllowed"] = allowed
            tracked[i + 1] = value
            changed = true
        }
        guard changed,
              let newData = try? PropertyListSerialization.data(fromPropertyList: tracked, format: .binary, options: 0) else { return false }
        plist["trackedApplications"] = newData
        guard let out = try? PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0) else { return false }
        do { try out.write(to: url, options: .atomic) } catch { return false }
        return true
    }
}
