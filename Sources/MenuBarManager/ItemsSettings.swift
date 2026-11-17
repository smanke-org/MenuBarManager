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

/// Settings › Items: the three sections, each in menu bar order. Moving an app here
/// moves its items in the bar, the same as a ⌘-drag across the chevron.
struct ItemsSettings: View {
    @State private var apps: [MenuBarApp] = []
    @State private var moving: String?
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
            Section { Text("This version of macOS doesn't offer the menu bar hiding Menu Bar Manager uses.") }
        } else {
            Section {
                Text("Items right of the chevron are Shown. Items left of it are Hidden until you click the chevron. ⌘-drag an item across the chevron, or use Move To here; both do the same thing.")
                    .foregroundStyle(.secondary)
            }
            ForEach(MenuSection.allCases) { section in
                Section(section.title) {
                    let members = apps.filter { hider.section(for: $0.bundleID) == section }
                    if members.isEmpty {
                        Text(section == .alwaysHidden ? "None. Apps here stay hidden even when you click the chevron; Option-click shows them." : "None")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(members) { app in row(app, in: section) }
                }
            }
            .onAppear(perform: reload)
        }
    }

    private func row(_ app: MenuBarApp, in section: MenuSection) -> some View {
        LabeledContent {
            if moving == app.bundleID {
                ProgressView().controlSize(.small)
            } else {
                Menu("Move To") {
                    ForEach(MenuSection.allCases.filter { $0 != section }) { target in
                        Button(target.title) { move(app, to: target) }
                    }
                }
                .fixedSize()
            }
        } label: {
            Label {
                Text(app.name)
            } icon: {
                if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 16, height: 16) }
            }
        }
    }

    private func move(_ app: MenuBarApp, to section: MenuSection) {
        moving = app.bundleID
        Task {
            await MenuBarController.shared.move(app.bundleID, to: section)
            moving = nil
            reload()
        }
    }

    private func reload() {
        let me = Bundle.main.bundleIdentifier ?? ""
        let ids = Set(MenuBarItems.drawn().compactMap(\.bundleID)).union(hider.sections.keys)
            .filter { !$0.hasPrefix("com.apple.") && $0 != me }
        let x = hider.lastSeenX
        apps = ids.map(MenuBarApp.init(bundleID:))
            .filter { $0.url != nil }
            .sorted { (x[$0.bundleID] ?? .infinity, $0.name) < (x[$1.bundleID] ?? .infinity, $1.name) }
    }
}
