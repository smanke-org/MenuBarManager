import SwiftUI

/// An app with menu bar items, as listed in Settings › Items.
struct MenuBarApp: Identifiable, Hashable {
    let bundleID: String
    var id: String { bundleID }
    var url: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }
    var name: String {
        guard let url else { return bundleID }
        return Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? url.deletingPathExtension().lastPathComponent
    }
    var icon: NSImage? { url.map { NSWorkspace.shared.icon(forFile: $0.path) } }
}

/// Settings › Items: every app with menu bar items, and the section they belong in.
struct ItemsSettings: View {
    @State private var apps: [MenuBarApp] = []
    private var hider: AppHider { .shared }

    var body: some View {
        if !AXIsProcessTrusted() {
            Section {
                Text("To list your menu bar items, Menu Bar Manager needs Accessibility access.")
                Button("Open Accessibility Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        } else if !hider.isAvailable {
            Section {
                Text("This version of macOS doesn't offer the menu bar hiding Menu Bar Manager uses.")
            }
        } else {
            Section {
                ForEach(apps) { app in
                    Picker(selection: Binding(
                        get: { hider.section(for: app.bundleID) },
                        set: { hider.setSection($0, for: app.bundleID) })) {
                        ForEach(MenuSection.allCases) { Text($0.title).tag($0) }
                    } label: {
                        Label {
                            Text(app.name)
                        } icon: {
                            if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 16, height: 16) }
                        }
                    }
                }
            } footer: {
                Text("macOS hides menu bar items by app, so all of an app's items share one section.")
            }
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        let inBar = MenuBarItems.all().compactMap(\.bundleID)
        let ids = Set(inBar).union(hider.sections.keys)
            .subtracting(["com.apple.MenuBarAgent", "com.apple.systemuiserver", "com.apple.controlcenter", Bundle.main.bundleIdentifier ?? ""])
        apps = ids.map(MenuBarApp.init(bundleID:))
            .filter { $0.url != nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
