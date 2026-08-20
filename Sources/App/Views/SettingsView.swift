import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(LauncherLibraryModel.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue

    let embedded: Bool

    init(embedded: Bool = false) {
        self.embedded = embedded
    }

    var body: some View {
        Group {
            if embedded {
                settingsForm
            } else {
                NavigationStack {
                    settingsForm
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { dismiss() }
                            }
                        }
                }
            }
        }
    }

    private var settingsForm: some View {
        Form {
            Section("Language") {
                Picker("App Language", selection: $languageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.titleKey).tag(language.rawValue)
                    }
                }
                Text("Dav Launcher supports English and Hebrew. You can also leave it on Follow System.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                LabeledContent("Authorization", value: notificationStatusText)
                if library.notificationAuthorizationStatus == .notDetermined {
                    Button("Allow Notifications") {
                        Task { await library.requestNotificationAuthorization() }
                    }
                } else if library.notificationAuthorizationStatus == .denied {
                    Button("Open Settings") {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    }
                }
            }

            Section("Shortcuts Callback") {
                Text("At the end of your Shortcut, add Set Launcher State or Reset Launcher. The action can return the Control Center control to Idle or show Success or Error.")
            }

            Section("Direct Widget") {
                Text("The Dav Direct Launcher widget supports multiple SystemShortcut buttons and all Home Screen system widget sizes available to this iOS/iPadOS 27 build.")
            }

            Section("Shared Container") {
                LabeledContent("App Group", value: AppEnvironment.appGroupID)
                Text("The app, Control Center control and widgets share profiles and state through this App Group.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .task {
            await library.refreshNotificationAuthorizationStatus()
        }
    }

    private var notificationStatusText: String {
        switch library.notificationAuthorizationStatus {
        case .notDetermined: String(localized: "Not requested")
        case .denied: String(localized: "Denied")
        case .authorized: String(localized: "Allowed")
        case .provisional: String(localized: "Provisional")
        case .ephemeral: String(localized: "Ephemeral")
        @unknown default: String(localized: "Unknown")
        }
    }
}
