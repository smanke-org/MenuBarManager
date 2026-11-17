import AppKit
import SwiftUI

// MARK: - Content

/// One page of Help. `Help.resolve` swaps `{…}` tokens for the user's own settings, such
/// as their shortcuts, so the text matches what they've set up.
struct HelpTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let blocks: [HelpBlock]

    static func == (a: HelpTopic, b: HelpTopic) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor
enum HelpBlock {
    case text(String)
    case heading(String)
    /// Keys on the left, what they do on the right.
    case keys([(String, String)])
    case tip(String)

    var searchText: String {
        switch self {
        case .text(let s), .heading(let s), .tip(let s): Help.resolve(s)
        case .keys(let rows): rows.map { Help.resolve($0.0) + " " + Help.resolve($0.1) }.joined(separator: " ")
        }
    }
}

@MainActor
enum Help {
    /// `{shortcut}` shows the user's own key for showing and hiding the Hidden items.
    static func resolve(_ text: String) -> String {
        guard text.contains("{shortcut}") else { return text }
        let key = HotKeyCenter.shared.hotKey(for: .toggle)?.display ?? "(no shortcut set)"
        return text.replacingOccurrences(of: "{shortcut}", with: key)
    }

    /// The page each Settings pane's ? button opens.
    static func topic(forSettingsTab tab: String) -> String {
        switch tab {
        case "Items": "sections"
        default: "settings"
        }
    }

    static var topicIDs: String { topics.map(\.id).joined(separator: ", ") }

    static var topics: [HelpTopic] { [
        HelpTopic(id: "getting-started", title: "Getting Started", symbol: "sparkles", blocks: [
            .text("Menu Bar Manager tidies your menu bar. It puts a chevron in the menu bar and keeps the menu bar items of the apps you choose out of sight until you want them. Click the chevron to show them, and click it again to hide them."),
            .keys([
                ("Click the chevron", "Show or hide the Hidden items"),
                ("⌥-click the chevron", "Show the Always Hidden items too"),
                ("Right-click the chevron", "Settings, Help, updates, About and Quit"),
                ("{shortcut}", "Show or hide the Hidden items from anywhere"),
            ]),
            .heading("Allow access"),
            .text("To list other apps' menu bar items and move them, Menu Bar Manager needs access. Turn on Menu Bar Manager in System Settings › Privacy & Security › Device Control and Data Access. Settings › Items explains what is missing until then."),
            .heading("Run it from Applications"),
            .text("macOS 27 only lets the chevron stay in the menu bar while other apps' items are hidden when Menu Bar Manager runs from the Applications folder. Keep it there, and open it from there."),
            .tip("Quitting Menu Bar Manager brings every hidden item back, so nothing stays hidden by accident. Quitting asks first; turn off \"Ask before quitting\" in Settings › General, or tick \"Don't ask again\" when it asks."),
        ]),

        HelpTopic(id: "sections", title: "Shown, Hidden and Always Hidden", symbol: "menubar.rectangle", blocks: [
            .text("Every app with menu bar items is in one of three sections. Sections work by app: all of an app's items go together."),
            .keys([
                ("Shown", "Always in the menu bar, right of the chevron"),
                ("Hidden", "Out of sight until you click the chevron, left of it"),
                ("Always Hidden", "Out of sight until you ⌥-click the chevron"),
            ]),
            .text("Pick each app's section in Settings › Items. The list follows the order of the menu bar, and Move To puts an app in another section at once. Apple's own items, like Control Center and the clock, never move."),
            .heading("⌘-drag across the chevron"),
            .text("You can also sort items in the menu bar itself. Hold ⌘ and drag an item left of the chevron to hide its app, or right of it to show it. An app with any item right of the chevron stays Shown."),
            .tip("A new app that adds a menu bar item while the bar is collapsed starts out Shown, so nothing disappears without you choosing it."),
        ]),

        HelpTopic(id: "showing", title: "Showing Hidden Items", symbol: "chevron.left", blocks: [
            .text("Click the chevron, press {shortcut}, or use the ways below to bring out the Hidden items. The chevron points right while they are out."),
            .heading("Hide again on its own"),
            .text("The Hidden items go away again after the time you choose in Settings › General › Hide again after: 15 seconds, 30 seconds (the first setting), 1 minute, 5 minutes or Never. While one of their menus is open, Menu Bar Manager waits for it to close."),
            .heading("Hover and scroll"),
            .text("Turn on \"Show when the pointer rests on the chevron\" to show the Hidden items when you rest the pointer on the chevron for a moment. Turn on \"Show or hide by scrolling over the menu bar\" to show them by scrolling one way anywhere over the menu bar, and hide them by scrolling the other way. Both are off at first."),
            .heading("Screens with a notch"),
            .text("On a MacBook with a notch there is rarely room for more items. So when you show the Hidden items from a screen with a notch, your Shown items step aside while the Hidden ones are out, and come back when they hide. Turn this off in Settings › General. On other displays the Hidden items simply join the bar."),
            .text("If the chevron itself ends up behind the notch, Menu Bar Manager sets aside the narrowest Shown app with a single item until the chevron fits again."),
        ]),

        HelpTopic(id: "shortcuts", title: "Shortcut", symbol: "keyboard", blocks: [
            .text("Press {shortcut} anywhere to show or hide the Hidden items. The first shortcut is ⌃⌥⌘B."),
            .text("To change it, click the shortcut in Settings › General › Show or hide with, and press the new keys. You can also clear it."),
            .tip("ShortcutsLens can list this shortcut and change it for you."),
        ]),

        HelpTopic(id: "settings", title: "Settings and Updates", symbol: "gearshape", blocks: [
            .text("Right-click the chevron and choose Settings…, or press ⌘, while Menu Bar Manager is in front. Settings › General has the appearance (System, Light or Dark), opening at login, asking before quitting, and whether Menu Bar Manager also shows in the Dock. The chevron always stays in the menu bar: it is how you use the app."),
            .text("With \"Show in Dock\" on, right-click the Dock icon for Settings. Opening Menu Bar Manager again from Applications or Spotlight opens Settings too."),
            .text("While ToolHUD is running, Menu Bar Manager's menu also shows as a submenu of ToolHUD's menu. The chevron stays where it is. Turn this off with \"Put in ToolHUD's menu while ToolHUD is running\" in Settings › General."),
            .heading("Sync"),
            .text("Turn on \"Sync settings with your other Macs\" to keep each app's section, the hide delay, the shortcut, hover and scroll, the notch setting, the appearance and the update choices the same on every Mac signed in to your iCloud account. They travel through your iCloud Drive."),
            .heading("Updates"),
            .text("Menu Bar Manager checks for new versions as often as you choose. It can install them automatically (never while the Hidden items are out), ask first, or never check. Check for Updates… in the chevron's menu checks right away."),
        ]),

        HelpTopic(id: "troubleshooting", title: "Troubleshooting", symbol: "wrench.and.screwdriver", blocks: [
            .heading("The chevron disappeared"),
            .text("Make sure Menu Bar Manager runs from the Applications folder. If you have many items on a screen with a notch, hide a few apps in Settings › Items so the chevron has room."),
            .heading("Settings › Items is empty"),
            .text("Menu Bar Manager needs access to see other apps' menu bar items. Turn it on in System Settings › Privacy & Security › Device Control and Data Access, then open Settings again."),
            .heading("An item came back after I hid it"),
            .text("Check its app's section in Settings › Items. If you ⌘-dragged one of its items right of the chevron, the app is Shown again."),
            .heading("Something is still hidden after quitting"),
            .text("Quitting brings every item back. If an app's items are still missing, quit and reopen that app."),
        ]),
    ] }
}

// MARK: - Window

@Observable
@MainActor
final class HelpState {
    var selection: String? = "getting-started"
    var query = ""
}

@MainActor
final class HelpWindow: NSObject, NSWindowDelegate {
    static let shared = HelpWindow()

    let state = HelpState()
    private(set) var window: NSWindow?

    /// Opens Help, on `topic` when given.
    func show(topic: String? = nil) {
        if let topic { state.query = ""; state.selection = topic }
        if window == nil {
            let hosting = NSHostingController(rootView: HelpView(state: state))
            hosting.sizingOptions = []
            let window = NSWindow(contentViewController: hosting)
            window.title = "\(AppInfo.name) Help"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            let screen = NSScreen.main?.visibleFrame.height ?? 800
            window.setContentSize(NSSize(width: 820, height: min(600, screen - 80)))
            window.contentMinSize = NSSize(width: 640, height: 400)
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("MenuBarManagerHelp")
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct HelpView: View {
    @Bindable var state: HelpState

    private var matches: [HelpTopic] {
        let query = state.query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return Help.topics }
        return Help.topics.filter { topic in
            topic.title.lowercased().contains(query) || topic.blocks.contains { $0.searchText.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(matches, selection: $state.selection) { topic in
                Label(topic.title, systemImage: topic.symbol).tag(topic.id)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
            .overlay {
                if matches.isEmpty { Text("No matches").foregroundStyle(.secondary) }
            }
        } detail: {
            if let topic = Help.topics.first(where: { $0.id == state.selection }) {
                HelpPage(topic: topic, query: state.query)
            } else {
                Text("Choose a topic").foregroundStyle(.secondary)
            }
        }
        .searchable(text: $state.query, placement: .sidebar, prompt: "Search Help")
        .onChange(of: state.query) {
            // Keep a matching topic on screen while searching.
            if let first = matches.first, !matches.contains(where: { $0.id == state.selection }) { state.selection = first.id }
        }
    }
}

struct HelpPage: View {
    let topic: HelpTopic
    let query: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label(topic.title, systemImage: topic.symbol)
                    .font(.largeTitle.weight(.semibold))
                    .padding(.bottom, 4)
                ForEach(Array(topic.blocks.enumerated()), id: \.offset) { _, block in
                    view(for: block)
                }
            }
            .padding(28)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func view(for block: HelpBlock) -> some View {
        switch block {
        case .text(let s):
            Text(Help.resolve(s)).fixedSize(horizontal: false, vertical: true)
        case .heading(let s):
            Text(Help.resolve(s)).font(.title3.weight(.semibold)).padding(.top, 8)
        case .tip(let s):
            Label { Text(Help.resolve(s)).fixedSize(horizontal: false, vertical: true) } icon: {
                Image(systemName: "lightbulb").foregroundStyle(.yellow)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        case .keys(let rows):
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    let keys = Help.resolve(row.0), what = Help.resolve(row.1)
                    let hit = !query.isEmpty && (keys + " " + what).lowercased().contains(query.lowercased())
                    GridRow {
                        Text(keys)
                            .font(.body.monospaced().weight(.medium))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                            // The same key column width in every table on every page.
                            .frame(width: 210, alignment: .leading)
                        Text(what).fixedSize(horizontal: false, vertical: true)
                    }
                    .background(hit ? Color.yellow.opacity(0.25) : .clear)
                }
            }
        }
    }
}

/// The round "?" button macOS puts in the corner of settings panes.
struct HelpButton: NSViewRepresentable {
    let topic: String

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "", target: context.coordinator, action: #selector(Coordinator.open))
        button.bezelStyle = .helpButton
        button.toolTip = "\(AppInfo.name) Help"
        button.setAccessibilityLabel("Help")
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) { context.coordinator.topic = topic }

    func makeCoordinator() -> Coordinator { Coordinator(topic: topic) }

    @MainActor
    final class Coordinator: NSObject {
        var topic: String
        init(topic: String) { self.topic = topic }
        @objc func open() { HelpWindow.shared.show(topic: topic) }
    }
}
