import SwiftUI

struct GeneralSettings: View {
    @Bindable var settings = AppSettings.shared
    @Bindable var hub = MenuHub.shared
    let launchAtLogin: LaunchAtLogin
    @State private var trusted = AXIsProcessTrusted()

    @AppStorage(AppSettings.Key.autoCollapseDelay) private var delay = 30.0
    @AppStorage(AppSettings.Key.showOnHover) private var showOnHover = false
    @AppStorage(AppSettings.Key.showOnScroll) private var showOnScroll = false
    @AppStorage(AppSettings.Key.swapOnNotch) private var swapOnNotch = true
    @State private var hotKey = HotKeyCenter.shared.hotKey(for: .toggle)

    var body: some View {
        Form {
            if !trusted {
                Section {
                    Label("Menu Bar Manager can't see other apps' menu bar items yet. Turn on Menu Bar Manager in Privacy & Security › Device Control and Data Access.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Open Privacy Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
            }
            Section("Hidden items") {
                LabeledContent("Show or hide with") {
                    ShortcutRecorder(hotKey: Binding(get: { hotKey }, set: { key in
                        hotKey = key
                        HotKeyCenter.shared.save(key, for: .toggle)
                        HotKeyCenter.shared.apply()
                    }), action: .toggle)
                }
                Toggle("Show when the pointer rests on the chevron", isOn: $showOnHover)
                Toggle("Show or hide by scrolling over the menu bar", isOn: $showOnScroll)
                Toggle("On a screen with a notch, set Shown items aside while hidden ones are out", isOn: $swapOnNotch)
                Picker("Hide again after", selection: $delay) {
                    Text("15 seconds").tag(15.0)
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                    Text("5 minutes").tag(300.0)
                    Text("Never").tag(0.0)
                }
            }
            Section {
                AppearancePicker()
                Caption(AppAppearance.footer(appName: AppInfo.name))
            }
            Section {
                Toggle("Open Menu Bar Manager at login", isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.set($0) }))
                    .disabled(!LaunchAtLogin.isInstalled && !launchAtLogin.isEnabled)
                if !LaunchAtLogin.isInstalled && !launchAtLogin.isEnabled {
                    Caption("Only the copy of Menu Bar Manager in Applications can open at login.")
                }
                if launchAtLogin.needsApproval {
                    HStack {
                        Caption("Waiting for approval in Login Items.")
                        Button("Open Login Items") { launchAtLogin.openLoginItemsSettings() }.controlSize(.small)
                    }
                }
                Toggle("Ask before quitting", isOn: $settings.confirmQuit)
                    .help("Quitting Menu Bar Manager asks first, so a stray ⌘Q doesn't bring every hidden item back.")
            }
            Section {
                Toggle("Show in Dock", isOn: $settings.showInDock)
                    .help("Adds a Dock icon whose right-click menu opens Settings.")
                Toggle("Put in ToolHUD’s menu while ToolHUD is running", isOn: $hub.foldIntoToolHUD)
                    .help("ToolHUD shows the chevron's menu as a submenu of its own. The chevron stays in the menu bar.")
            } footer: {
                Caption("The chevron always stays in the menu bar; right-click it for Settings, Help, updates and Quit.")
            }
            SyncUpdateSections()
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin.refresh()
            trusted = AXIsProcessTrusted()
            hotKey = HotKeyCenter.shared.hotKey(for: .toggle)
        }
    }
}
