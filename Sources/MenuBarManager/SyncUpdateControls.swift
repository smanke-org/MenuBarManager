import SwiftUI

/// The iCloud settings sync and update choices, as sections of General's grouped Form.
struct SyncUpdateSections: View {
    @ObservedObject private var sync = SettingsSync.shared
    @ObservedObject private var updater = AutoUpdater.shared

    var body: some View {
        Section {
            Toggle("Sync settings with your other Macs", isOn: $sync.isEnabled)
            if sync.isEnabled {
                LabeledContent {
                    Button("Sync Now") { sync.syncNow() }.controlSize(.small)
                } label: {
                    Group {
                        if let error = sync.lastError {
                            Text(error).foregroundStyle(.red)
                        } else if let date = sync.lastSynced {
                            Text("Synced \(date.formatted(date: .omitted, time: .shortened))\(sync.lastSource.map { $0 == (Host.current().localizedName ?? "") ? "" : " from \($0)" } ?? "")")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Waiting for iCloud Drive…").foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
            }
        } header: {
            Text("iCloud")
        } footer: {
            Caption("Each app's section, when hidden items hide again, the shortcut, hover and scroll, the notch setting, the appearance and accent color, asking before quitting, the Dock icon, ToolHUD's menu and the update choices follow you to every Mac signed in to the same iCloud account with sync turned on. They travel through your iCloud Drive.")
        }

        Section {
            Picker("When an update is available", selection: $updater.policy) {
                ForEach(UpdatePolicy.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            if updater.policy != .off {
                UpdateIntervalPicker(interval: $updater.interval)
            }
            if let staged = updater.staged {
                LabeledContent("Version \(staged.version) is ready") {
                    Button("Install Now") { updater.installNow() }
                }
            }
            LabeledContent("Version \(AppInfo.displayVersion)") {
                HStack {
                    Button("What's New…") { SettingsWindow.shared.showWhatsNew() }
                    Button("Check Now") { UpdateController.checkForUpdates() }
                }
            }
            if let error = updater.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            if updater.policy != .off && !updater.notificationsAllowed {
                LabeledContent {
                    Button("Open Notification Settings") { AutoUpdater.openNotificationSettings() }
                } label: {
                    Label("Notifications are off for Menu Bar Manager, so update news only shows in the chevron's menu.", systemImage: "bell.slash")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Updates")
        } footer: {
            Caption(updateFooter)
        }
        .onAppear { updater.refreshNotificationStatus() }
    }

    private var updateFooter: String {
        switch updater.policy {
        case .automatic:
            return "Menu Bar Manager checks \(updater.interval.phrase). A new version installs itself when the Hidden items aren't showing, no app is presenting or keeping the screen awake, and your Mac hasn't been used for 2 minutes. You'll get a notification when it's done."
        case .ask:
            return "Menu Bar Manager checks \(updater.interval.phrase) and sends a notification when a new version is out. Nothing installs until you choose to."
        case .off:
            return "Menu Bar Manager won't look for updates on its own. Use Check Now whenever you like."
        }
    }
}
