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

            Section("Diagnostics") {
                LabeledContent(
                    "App Group Container",
                    value: AppEnvironment.sharedContainerURL == nil ? "MISSING" : "Available"
                )
                .foregroundStyle(AppEnvironment.sharedContainerURL == nil ? .red : .primary)

                LabeledContent("Effective App Group", value: AppEnvironment.appGroupID)
                LabeledContent("Configured App Group", value: AppEnvironment.configuredAppGroupID)
                LabeledContent("Resolution", value: AppEnvironment.appGroupResolutionDescription)

                if let teamIdentifier = AppEnvironment.sideStoreTeamIdentifier {
                    LabeledContent("SideStore Team", value: teamIdentifier)
                }

                Text("Candidates: \(AppEnvironment.appGroupCandidates.joined(separator: ", "))")
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)

                if let path = AppEnvironment.sharedContainerURL?.path {
                    Text(path)
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                } else {
                    Text("The app and WidgetKit extension cannot share profiles or extension logs when this container is missing. The SideStore-ready IPA embeds the App Group entitlement so SideStore can provision it, and the app also checks SideStore's Team-ID-suffixed group name.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Text("Files log: \(DiagnosticLog.filesLocationDescription)")
                    .font(.footnote)
                    .textSelection(.enabled)

                Text("After testing a Control Center button, reopen Dav Launcher or tap Sync Log to Files. Extension events are written to the App Group first, then mirrored into the app's Documents folder.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Sync Log to Files") {
                    DiagnosticLog.recordEnvironment("settings.manualLogSync")
                    DiagnosticLog.syncSharedLogToDocuments()
                }

                Button("Clear Diagnostic Log", role: .destructive) {
                    DiagnosticLog.clear()
                    DiagnosticLog.recordEnvironment("settings.logCleared")
                    DiagnosticLog.syncSharedLogToDocuments()
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
            DiagnosticLog.syncSharedLogToDocuments()
            DiagnosticLog.recordEnvironment("settings.opened")
            DiagnosticLog.syncSharedLogToDocuments()
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
